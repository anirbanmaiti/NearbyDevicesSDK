//
//  BluetoothManager.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

@preconcurrency import Combine
import Foundation

/// This class acts as a wrapper around `CoreCentralManager` providing async APIs.
actor BluetoothManager: BluetoothManaging {

    // MARK: API
    var authorization: CurrentValueStream<BluetoothAuthorization> {
        get async {
            await context.authorizationStream
        }
    }

    var bluetoothState: CurrentValueStream<BluetoothState> {
        get async {
            await context.bluetoothStateStream
        }
    }

    func ensurePoweredOn() async throws {
        do {
            try await waitUntilReady()
        } catch {
            logger?.logDebug("Bluetooth is not ready. \(error)")
        }
        try ensure(.poweredOn)
    }

    var scanningState: BluetoothScanningState {
        get async {
            await context.currentScanningState
        }
    }

    var scanningStateStream: AsyncStream<BluetoothScanningState> {
        get async {
            await context.scanningState.dropFirst().removeDuplicates().stream
        }
    }

    var scanResultStream: AsyncStream<PeripheralDiscoveryEvent> {
        get async {
            await context.scanResult.compactMap { $0 }.stream
        }
    }

    var connectionEventsStream: AsyncStream<PeripheralConnectionEvent> {
        get async {
            await context.connectionEvent.compactMap { $0 }.stream
        }
    }

    func initializeBluetooth(config: BluetoothManagerConfiguration) async {
        guard centralManager == nil, let factory = factory else { return }
        logger?.logDebug("Initializing bluetooth stack.")

        // Initialize core bluetooth central manager
        let centralManager = factory.makeCoreCentralManager(
            delegate: delegateWrapper,
            dispatcher: dispatcher,
            config: config
        )
        self.centralManager = centralManager
        await context.setupSubscriptions()

        // Updates central state
        await context.setBluetoothState(BluetoothState(centralManager.state))

        // Updates scanning state
        await context.updateScanningState(centralManager.isScanning)

        // Setup Subscriptions for central state change etc.
        setupBluetoothManagerSubscriptions(centralManager)
    }

    func scanForPeripherals(with request: PeripheralScanRequest) async throws {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        // await for bluetooth ready state
        try await ensurePoweredOn()

        var options: [String: Any]?
        if request.allowDuplicates {
            options = [CoreCentralManagerScanOptionAllowDuplicatesKey: true]
        }
        await context.setScanRequest(request)
        logger?.logInfo("Starting core bluetooth scan with Request:\(request).", tag: .ble)
        centralManager.scanForPeripherals(withServices: Array(request.serviceUUIDs), options: options)
    }

    func stopPeripheralScan() async throws {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }

        // await for bluetooth ready state
        try await ensurePoweredOn()

        // avoid an API MISUSE warning on the console if bluetooth is powered off or unsupported or unauthorized
        if await bluetoothState.value == .poweredOn {
            centralManager.stopScan()
            logger?.logInfo("Stopping core bluetooth scan.", tag: .ble)
        }
        await context.setScanRequest(nil)
    }

    func retrieveRestoredPeripheralsIDs() async throws -> [UUID] {
        try await ensurePoweredOn()
        return await context.restoredPeripheralsIDs
    }

    /// Returns list of `CorePeripheralRepresentable`s by their identifiers which are known to `BluetoothManager`.
    /// - parameter identifiers: List of `CorePeripheralRepresentable`'s identifiers which should be retrieved.
    /// - returns: Retrieved `CorePeripheralRepresentable`s.
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) async throws -> [CorePeripheralRepresentable] {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        try ensure(.poweredOn)
        return centralManager.retrievePeripherals(withIdentifiers: identifiers)
    }

    /// Returns list of the `CorePeripheralRepresentable`s which are currently connected to the `BluetoothManager` and contain
    /// all of the specified `Service`'s UUIDs.
    ///
    /// - parameter serviceUUIDs: A list of `Service` UUIDs
    /// - returns: Retrieved `CorePeripheralRepresentable`s. They are in connected state and contain all of the
    /// `Service`s with UUIDs specified in the `serviceUUIDs` parameter.
    func retrieveConnectedPeripherals() throws -> [CorePeripheralRepresentable] {
        guard let centralManager = centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        let serviceUUIDs = Array(ServiceCBUUIDContainer.all)
        return centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs)
    }

    func connect(peripheral: CorePeripheralRepresentable) async throws {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        // await for bluetooth ready state
        try await ensurePoweredOn()

        logger?.logDebug("> \(String(describing: Swift.type(of: self))): Attempting to connect to \(peripheral)", tag: .ble)
        try centralManager.connect(peripheral, options: nil)
    }

    func cancelPeripheralConnection(peripheral: CorePeripheralRepresentable) async throws {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        try ensure(.poweredOn)

        logger?.logDebug("> \(String(describing: Swift.type(of: self))): Disconnecting from \(peripheral)", tag: .ble)
        try centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: Initialization
    /// Creates new `BluetoothManager`
    /// - Parameters :
    ///  - factory: Factory to create underlying CoreCentralManager.
    ///  - context: Bluetooth manager concurrency context.
    ///  - delegateWrapper: Bluetooth manager delegate wrapper.
    ///  - queue: Queue on which bluetooth callbacks are received.
    ///  - bluetoothReadyTimeout: Bluetooth ready state transition timeout.
    ///  - logger: Logger object.
    init(factory: BluetoothCreating,
         context: BluetoothManagerContext,
         delegateWrapper: BluetoothManagerDelegateWrapper,
         queue: DispatchQueue,
         bluetoothReadyTimeout: TimeInterval,
         logger: NDLoggerProtocol?) {
        self.factory = factory
        self.context = context
        self.delegateWrapper = delegateWrapper
        self.dispatcher = queue
        self.bluetoothReadyTimeout = bluetoothReadyTimeout
        self.logger = logger
    }

    /// Creates new `BluetoothManager` instance. By default all operations and events are executed and received on main thread.
    ///
    /// - Parameter factory: Factory to create underlying CoreCentralManager
    /// - Parameter dispatcher: Queue on which bluetooth callbacks are received. By default main thread is used.
    /// - Parameter bluetoothReadyTimeout: Bluetooth ready state transition timeout.
    /// - Parameter logger: Logger object.
    init(factory: BluetoothCreating,
         dispatcher: DispatchQueue = DispatchQueue.bluetoothQueue,
         bluetoothReadyTimeout: TimeInterval = 5.0,
         logger: NDLoggerProtocol?) {

        let delegateWrapper = BluetoothManagerDelegateWrapper(logger: logger)
        let context = BluetoothManagerContext(delegateWrapper: delegateWrapper, logger: logger)
        self.init(factory: factory,
                  context: context,
                  delegateWrapper: delegateWrapper,
                  queue: dispatcher,
                  bluetoothReadyTimeout: bluetoothReadyTimeout,
                  logger: logger)
    }

    // MARK: - Private
    private func setupBluetoothManagerSubscriptions(_ centralManager: CoreCentralManaging) {
        centralManager.isScanningPublisher.stream.sink { [weak self] isScanning in
            await self?.context.updateScanningState(isScanning)
        }
    }

    /// Waits until Bluetooth is ready. If the Bluetooth state is unknown or resetting, it
    /// will wait until a `centralManagerDidUpdateState` message is received. If Bluetooth is powered off,
    /// unsupported or unauthorized, an error will be thrown. Otherwise we'll continue.
    private func waitUntilReady() async throws {
        guard let isBluetoothReadyResult = await bluetoothState.value.isBluetoothReady() else {
            logger?.logInfo("Waiting for bluetooth to be ready...", tag: .ble)

            try await context.waitUntilReadyExecutor.enqueue(timeout: bluetoothReadyTimeout) { [weak self] in
                await self?.context.flushReadyExecutorIfNeeded()
            }
            return
        }

        switch isBluetoothReadyResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    /// Ensure that `state` is otherwise throws BluetoothError
    /// - parameter state: `BluetoothState` which should be present.
    /// - throws: `BluetoothError`
    private func ensure(_ state: BluetoothState) throws {
        guard let centralManager else {
            throw BluetoothError.bluetoothManagerUnavailable
        }
        let centralState = BluetoothState(centralManager.state)
        guard state == centralState else {
            throw BluetoothError(state: centralState)
        }
    }

    // MARK: Private properties
    private var centralManager: CoreCentralManaging?
    private var context: BluetoothManagerContext
    private let delegateWrapper: BluetoothManagerDelegateWrapper
    private weak var factory: BluetoothCreating?
    private let dispatcher: DispatchQueue
    private let bluetoothReadyTimeout: TimeInterval
    private let logger: NDLoggerProtocol?
}
