//
//  BluetoothManagerContext.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

@preconcurrency import Combine
import Foundation

/// Contains the objects necessary to track Central Managers's events and state.
actor BluetoothManagerContext {

    /// Central Manager authorization publisher.
    let bluetoothAuthorization = PassthroughSubject<BluetoothAuthorization, Never>()

    var authorizationStream: CurrentValueStream<BluetoothAuthorization> {
        CurrentValueStream(
            publisher: bluetoothAuthorization.removeDuplicates().eraseToAnyPublisher(),
            initialValue: .current()
        )
    }

    func updateBluetoothAuthorization() async {
        bluetoothAuthorization.send(.current())
    }

    /// Central Manager state publisher.
    let bluetoothState = CurrentValueSubject<BluetoothState, Never>(.unknown)

    var bluetoothStateStream: CurrentValueStream<BluetoothState> {
        CurrentValueStream(
            publisher: bluetoothState.removeDuplicates().eraseToAnyPublisher(),
            initialValue: bluetoothState.value
        )
    }

    /// Publishes central manager state.
    func setBluetoothState(_ state: BluetoothState) async {
        guard bluetoothState.value != state else { return }
        bluetoothState.send(state)
        await flushReadyExecutorIfNeeded()
    }

    /// Scanning state publisher.
    let scanningState = CurrentValueSubject<BluetoothScanningState, Never>(.idle)

    /// Current value of the scanning state, safe to read across actor boundaries.
    var currentScanningState: BluetoothScanningState {
        scanningState.value
    }

    /// Discovery event publisher.
    let scanResult = PassthroughSubject<PeripheralDiscoveryEvent, Never>()

    /// set scan request.
    func setScanRequest(_ request: PeripheralScanRequest?) {
        scanRequest = request
    }

    /// Publishes scan result.
    func setScanResult(_ event: PeripheralDiscoveryEvent) {
        scanResult.send(event)
    }

    /// Update scanning state.
    func updateScanningState(_ isScanning: Bool) {
        guard let isReady = bluetoothState.value.isReady, isReady, isScanning else {
            updateScanningStateIfNeeded(.idle)
            return
        }
        if let scanRequest {
            updateScanningStateIfNeeded(.scanning(scanRequest))
        } else {
            logger?.logDebug("ERROR: BluetoothManager scanning without scan request.")
        }
    }

    /// Restored peripheral IDs
    var restoredPeripheralsIDs: [UUID] = []
    func setBluetoothRestoredPeripherals(_ peripherals: [CorePeripheralRepresentable]) {
        restoredPeripheralsIDs = peripherals.map { $0.identifier }
    }

    /// Connection event publisher.
    let connectionEvent = CurrentValueSubject<PeripheralConnectionEvent?, Never>(nil)

    /// Publishes peripheral connection event.
    func setConnectionEvent(_ event: PeripheralConnectionEvent) {
        connectionEvent.send(event)
    }

    let waitUntilReadyExecutor: AsyncSerialExecutor<Void>

    func flushReadyExecutorIfNeeded() async {
        guard let isBluetoothReadyResult = bluetoothState.value.isBluetoothReady() else { return }
        await waitUntilReadyExecutor.flush(isBluetoothReadyResult)
    }

    func flush(error: Error) async {
        for flushableExecutor in flushableExecutors {
            await flushableExecutor.flush(error: error)
        }
    }

    // MARK: Initialization
    init(delegateWrapper: BluetoothManagerDelegateWrapper, logger: NDLoggerProtocol?) {
        self.delegateWrapper = delegateWrapper
        self.logger = logger
        let executor = AsyncSerialExecutor<Void>()
        self.waitUntilReadyExecutor = executor
        self.flushableExecutors = [executor]
        Task {
            await setupSubscriptions()
        }
    }

    deinit {
        cancellableTasks.forEach { $0.cancel() }
        cancellableTasks.removeAll()
        bluetoothAuthorization.send(completion: .finished)
        scanningState.send(completion: .finished)
        scanResult.send(completion: .finished)
        connectionEvent.send(completion: .finished)
        bluetoothState.send(completion: .finished)
    }

    func setupSubscriptions() {
        guard !isSubscribed else { return }
        isSubscribed = true
        delegateWrapper?.eventStream.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .didDiscover(let discoveryEvent):
                await setScanResult(discoveryEvent)
            case .didUpdateState(state: let state):
                await setBluetoothState(state)
                await updateBluetoothAuthorization()
            }
        }
        .store(in: &cancellableTasks)

        delegateWrapper?.connectionEventStream.sink { [weak self] event in
            await self?.setConnectionEvent(event)
        }
        .store(in: &cancellableTasks)
    }

    // MARK: Private
    private func updateScanningStateIfNeeded(_ state: BluetoothScanningState) {
        guard scanningState.value != state else { return }
        scanningState.send(state)
    }

    private weak var delegateWrapper: BluetoothManagerDelegateWrapper?
    private let logger: NDLoggerProtocol?
    private var scanRequest: PeripheralScanRequest?
    private var flushableExecutors: [FlushableExecutor] = []
    private var cancellableTasks = Set<Task<Void, Error>>()
    private var isSubscribed = false
}
