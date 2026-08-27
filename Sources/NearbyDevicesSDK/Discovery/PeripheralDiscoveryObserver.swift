//
//  PeripheralDiscoveryObserver.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Combine
import Foundation

/// Observes central manager discovery events, batches them based on maxDelay and maxEvent count.
/// Also removes duplicates within the batch.
protocol PeripheralDiscoveryObservable: Sendable {

    /// Batched peripheral discovery event stream.
    var peripheralDiscoveryStream: AsyncStream<[PeripheralDiscoveryEvent]> { get async }

    /// Initialization.
    ///
    /// - Parameters:
    ///  - centralScanManager: Central scanner object.
    ///  - configuration: configuration object. see `PeripheralDiscoveryConfiguration`
    ///  - logger: logger object.
    init(bluetoothScanManager: BluetoothScanManaging, configuration: PeripheralDiscoveryConfiguration, logger: NDLoggerProtocol?)
}

struct PeripheralDiscoveryConfiguration {

    /// Default confirguration
    static let `default` = PeripheralDiscoveryConfiguration(maxDelay: 1.0, maxEventCount: 100)

    /// Dispatch peripherals discovered within a time interval (seconds).
    let maxDelay: TimeInterval

    /// Dispatch peripherals if maximum event count reached.
    let maxEventCount: Int
}

actor PeripheralDiscoveryObserver: PeripheralDiscoveryObservable {

    // MARK: API
    var peripheralDiscoveryStream: AsyncStream<[PeripheralDiscoveryEvent]> {
        get async {
            await setupSubscriptions()
            return processedEventsSubject.eraseToAnyPublisher().stream
        }
    }

    // MARK: Initialization
    init(bluetoothScanManager: BluetoothScanManaging,
         configuration: PeripheralDiscoveryConfiguration,
         logger: NDLoggerProtocol?) {
        self.bluetoothScanManager = bluetoothScanManager
        self.configuration = configuration
        self.logger = logger
        Task {
            await setupSubscriptions()
        }
    }

    deinit {
//        processedEventsSubject.send(completion: .finished)
        subscribedTasks.forEach { $0.cancel() }
        subscribedTasks.removeAll()
    }

    // MARK: Private
    private func setupSubscriptions() async {
        guard !isSubscribed else { return }
        isSubscribed = true
        await bluetoothScanManager.scanResultStream.sink {[weak self] event in
            guard let self else {
                return
            }
            await didDiscoverPeripheral(event: event)
        }
        .store(in: &subscribedTasks)
    }

    private func didDiscoverPeripheral(event: PeripheralDiscoveryEvent) {
        unprocessedEventReceipts.insert(event)

        if unprocessedEventReceipts.count == 1 {
            deliverPendingNotifications(after: configuration.maxDelay)
        } else if unprocessedEventReceipts.count == configuration.maxEventCount {
            deliverPendingNotificationsNow()
        }
    }

    private func deliverPendingNotifications(after duration: TimeInterval) {
        guard delayedTask == nil else { return }
        delayedTask = Task.delayed(byTimeInterval: duration) {
            guard !Task.isCancelled else { return }
            await self.deliverPendingNotificationsNow()
        }
    }

    private func deliverPendingNotificationsNow() {
        defer {
            delayedTask?.cancel()
            delayedTask = nil
        }
        guard !unprocessedEventReceipts.isEmpty else { return }
        processedEventsSubject.send(Array(unprocessedEventReceipts))
        unprocessedEventReceipts.removeAll()
    }

    private let bluetoothScanManager: BluetoothScanManaging
    private let configuration: PeripheralDiscoveryConfiguration
    private let logger: NDLoggerProtocol?

    private var unprocessedEventReceipts = Set<PeripheralDiscoveryEvent>()
    private let processedEventsSubject = PassthroughSubject<[PeripheralDiscoveryEvent], Never>()
    private var isSubscribed: Bool = false
    private var delayedTask: Task<(), Error>?
    private var subscribedTasks = Set<Task<Void, Error>>()
}

// MARK: - PeripheralDiscoveryObserver factory.
extension NearbyDiscoveryComponent {
    func makePeripheralDiscoveryObserver() -> PeripheralDiscoveryObservable {
        return PeripheralDiscoveryObserver(
            bluetoothScanManager: centralManager,
            configuration: .default,
            logger: logger
        )
    }
}
