//
//  ScanController.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

/// Centralized controller to manage system wide scan requests.
protocol ScanControlling: Sendable {

    /// current set of scan requests.
    var scanRequests: Set<ScanRequest> { get async }

    /// Scan request stream.
    var scanRequestStream: AsyncStream<Set<ScanRequest>> { get async }

    /// Adds a scan request.
    /// - Parameters:
    ///   - reason: Purpose of the scan request.
    ///   - duration: The time duration of the scan. If nil then the scan will continue to scan until `requestHandle.cancel()` is called.
    /// - Returns: `RequestHandlable` object which can be used to remove the request from the controller.
    func requestScan(reason: ScanRequestReason, duration: TimeInterval?) async -> RequestHandling

    /// Removes all scan request and stops bluetooth scan if needed.
    func stopAllScanRequest() async
}

actor ScanController: ScanControlling, RequestHandleDelegate {
    func requestHandleWasReleased(with uuid: UUID) async {
        guard let request = findRequest(uuid) else {
            return
        }
        await removeRequest(request)
    }

    var scanRequests: Set<ScanRequest> {
        get async {
            return requests
        }
    }

    var scanRequestStream: AsyncStream<Set<ScanRequest>> {
        requestSubject.stream
    }

    func requestScan(reason: ScanRequestReason, duration: TimeInterval?) async -> RequestHandling {
        let request = ScanRequest(reason: reason, duration: duration)
        logger?.logDebug("ScanController: adding scan request \(request).")
        requests.insert(request)
        do {
            try await fulfillRequests()
        } catch {
            logger?.logDebug("ScanController: Failed to fulfill scan request. \(error).")
        }

        if let duration {
            let delayedTask = Task.delayed(byTimeInterval: duration) { [weak self] in
                await self?.removeRequest(request)
            }
            watchdogTimers[request.identifier] = delayedTask
        }
        return RequestHandle(requestID: request.identifier, delegate: self)
    }

    func stopAllScanRequest() async {
        requests.removeAll()
        watchdogTimers.removeAll()
        recurringTask?.cancel()
        subscription.removeAll()
        do {
            try await fulfillRequests()
        } catch {
            logger?.logDebug("stop all scan request failed with error: \(error).")
        }
    }

    // MARK: Initialization
    init(bluetoothStateObserver: BluetoothStateObservable,
         bluetoothScanManager: BluetoothScanManaging,
         recurringScanInterval: TimeInterval?,
         logger: NDLoggerProtocol?,
         featureFlagProvider: NDFeatureFlagProviding) {
        self.bluetoothStateObserver = bluetoothStateObserver
        self.bluetoothScanManager = bluetoothScanManager
        self.recurringScanInterval = recurringScanInterval
        self.logger = logger
        self.featureFlagProvider = featureFlagProvider
        Task {
            await setupSubscriptions()
        }
    }

    // MARK: Private
    /// current set of scan requests.
    private var requests: Set<ScanRequest> = [] {
        didSet {
            guard requests != oldValue else { return }
            requestSubject.send(requests)
        }
    }

    private func findRequest(_ reason: ScanRequestReason) -> ScanRequest? {
        guard let request = requests.first(where: { $0.reason == reason }) else {
            return nil
        }
        return request
    }

    private func findRequest(_ identifier: UUID) -> ScanRequest? {
        guard let request = requests.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        return request
    }

    private func removeRequest(_ request: ScanRequest) async {
        logger?.logDebug("ScanController: Removing scan request \(request).")
        requests.remove(request)
        watchdogTimers[request.identifier]?.cancel()
        watchdogTimers[request.identifier] = nil
        do {
            try await fulfillRequests()
        } catch {
            logger?.logDebug("ScanController: Failed to fulfillRequests with error: \(error).")
        }
    }

    /// Resets the scanning if requests are in `requests` list.
    private func fulfillRequests() async throws {
        // Stop the scanning if its already scanning
        if case .scanning = await bluetoothScanManager.scanningState {
            do {
                recurringTask?.cancel()
                try await bluetoothScanManager.stopPeripheralScan()
            } catch {
                logger?.logDebug("Failed to stop scan. \(error)")
                throw error
            }
        }

        guard !requests.isEmpty else { return }

        let reasons = Set(requests.map(\.reason))
        do {
            try await bluetoothScanManager
                .scanForPeripherals(
                    with: PeripheralScanRequest(
                        scanReasons: reasons,
                        featureFlagProvider: featureFlagProvider
                    )
                )
            scheduleRecurringScanIfNeeded()
        } catch {
            logger?.logDebug("Failed to start scan. \(error)")
            throw error
        }
    }

    /// Schedules recurring scan reset if there any request in the requests list.
    private func scheduleRecurringScanIfNeeded() {
        guard let recurringScanInterval else { return }

        recurringTask?.cancel()
        guard !requests.isEmpty else {
            return
        }

        recurringTask = Task.delayed(byTimeInterval: recurringScanInterval) {[weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                logger?.logDebug("Recurring scan triggered.")
                try await fulfillRequests()
            } catch {
                logger?.logDebug("Recurring scan failed to fulfill requests.")
            }
        }
    }

    private func setupSubscriptions() async {
        await bluetoothStateObserver.bluetoothState.sink(dropFirst: true) { [weak self] state in
            guard let self else {
                return
            }
            logger?.logDebug("ScanController: Bluetooth state changed to \(state)")
            switch state {
            case .poweredOn:
                do {
                    try await fulfillRequests()
                } catch {
                    logger?.logDebug("ScanController: failed to start scan after Bluetooth power on")
                }
            default:
                break
            }
        }.store(in: &subscription)
    }

    private let bluetoothStateObserver: BluetoothStateObservable
    private let bluetoothScanManager: BluetoothScanManaging
    private let recurringScanInterval: TimeInterval?
    private let logger: NDLoggerProtocol?
    private let featureFlagProvider: NDFeatureFlagProviding

    private var watchdogTimers = [UUID: Task<()?, Error>]()
    private var recurringTask: Task<()?, Error>?
    private var subscription = Set<AnyCancellable>()
    private let requestSubject = PassthroughSubject<Set<ScanRequest>, Never>()
}

extension NearbyDevicesGate {
    func makeScanController() -> ScanControlling {
        ScanController(
            bluetoothStateObserver: centralManager,
            bluetoothScanManager: centralManager,
            recurringScanInterval: 120.0,
            logger: logger,
            featureFlagProvider: featureFlagProvider
        )
    }
}
