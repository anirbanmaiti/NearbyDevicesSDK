//
//  BlePeripheral.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

@preconcurrency import Combine
import Foundation

/// Provides async APIs to access ``CorePeripheralRepresentable``
final class BlePeripheral: Sendable {

    // MARK: API
    let peripheral: CorePeripheralRepresentable

    /// The UUID associated with the peripheral.
    var identifier: UUID { peripheral.identifier }

    /// Peripheral name associated with the peripheral.
    var name: String? { peripheral.name }

    /// The connection state of the peripheral.
    var state: PeripheralState {
        PeripheralState(peripheral.state)
    }
    /// Peripheral connection state stream
    var stateStream: AsyncStream<PeripheralState> {
        stateSubject.map { PeripheralState($0) }.removeDuplicates().eraseToAnyPublisher().stream
    }

    /// A list of a peripheral’s discovered services.
    var services: [CoreService]? { peripheral.services}

    /// Establishes a local connection.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or central manager connection delegate gets called.
    /// Multiple calls will be queued and put on waiting Task untill timeout or delegate gets called.
    /// - Parameter timeout: The timeout for the connect request (in seconds). If nil then the connect request will continue until successfully connected or fails to connect.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`, `.operationTimedOut`, `.peripheralConnectionFailed`
    func connect(timeout: TimeInterval?) async throws {
        try await perform {
            try await context.connectToPeripheralExecutor.enqueue(timeout: timeout) { [weak self] in
                guard let self else { return }

                if state == .connected {
                    logger?.logDebug("Peripheral \(identifier) is already connected state.", tag: .ble)
                    try? await context.connectToPeripheralExecutor.setWorkCompletedWithResult(.success(()))
                    return
                }

                do {
                    try await manager.connect(peripheral: peripheral)
                    publishPeripheralState()
                } catch {
                    logger?.logDebug("\(String(describing: Swift.type(of: self))): Failed to connect \(peripheral). \(error)", tag: .ble)
                    try? await context.connectToPeripheralExecutor.setWorkCompletedWithResult(.failure(error))
                }
            }
        }
    }

    /// Cancels an active or pending local connection.
    /// This call is non-blocking, that is, call will send disconnect request to central manager and return.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func disconnect() async throws {
        logger?.logDebug("\(String(describing: Swift.type(of: self))): Attempting to disconnect from \(peripheral)", tag: .ble)
        try await perform {
            guard state == .connecting || state == .connected else {
                logger?.logDebug("Unable to cancel connection: no connection to peripheral \(identifier) exists nor being attempted. State \(state)", tag: .ble)
                return
            }
            try await self.manager.cancelPeripheralConnection(peripheral: peripheral)
            publishPeripheralState()
        }
    }

    /// Retrieves the current RSSI value for the peripheral while connected to the central manager.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    /// - Throws: `BluetoothError.peripheralDisconnected`  `.operationTimedOut`
    func readRSSI() async throws -> Int {
        try await perform {
            return try await context.readRSSIExecutor.enqueue { [weak peripheral] in
                peripheral?.readRSSI()
            }
        }
    }

    // MARK: Services

    /// Discovers the specified services of the peripheral.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    /// - Throws: `BluetoothError.peripheralDisconnected` `.servicesDiscoveryFailed` `.operationTimedOut`
    func discoverServices(_ serviceUUIDs: [CoreUUID]?) async throws -> [CoreService] {
        try await perform {
            return try await self.context.discoverServiceExecutor.enqueue { [weak peripheral] in
                peripheral?.discoverServices(serviceUUIDs)
            }
        }
    }

    // MARK: Characteristics

    /// Discovers the specified characteristics of a service.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    /// - Throws: `BluetoothError.peripheralDisconnected` `.characteristicsDiscoveryFailed` `.operationTimedOut`
    func discoverCharacteristics(_ characteristicUUIDs: [CoreUUID]?, for service: CoreService) async throws -> [CoreCharacteristic] {
        try await perform {
            return try await context.discoverCharacteristicsExecutor.enqueue(withKey: service.uuid) { [weak self] in
                guard let self else { return }
                guard self.peripheral.state == .connected else {
                    try? await self.context.discoverCharacteristicsExecutor.setWorkCompletedForKey(service.uuid, result: .failure(BluetoothError.peripheralDisconnected(self.identifier, nil)))
                    return
                }
                self.peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
            }
        }
    }

    /// Retrieves the value of a specified characteristic.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    ///
    /// Note: Concurrent reads from different characteristics is supported.
    /// - Throws: `BluetoothError.peripheralDisconnected` `.characteristicReadFailed` `.operationTimedOut`
    func readValue(for characteristic: CoreCharacteristic) async throws -> Data? {
        try await perform {
            return try await context.readCharacteristicValueExecutor.enqueue(withKey: characteristic.uuid, timeout: bluetoothApiTimeout) { [weak self] in
                guard let self else { return }
                guard self.peripheral.state == .connected else {
                    try? await self.context.readCharacteristicValueExecutor.setWorkCompletedForKey(characteristic.uuid, result: .failure(BluetoothError.peripheralDisconnected(self.identifier, nil)))
                    return
                }

                self.peripheral.readValue(for: characteristic)
            }
        }
    }

    /// The maximum amount of data, in bytes, you can send to a characteristic in a single write type.
    func maximumWriteValueLength(for type: CoreCharacteristicWriteType) -> Int {
        peripheral.maximumWriteValueLength(for: type)
    }

    /// Writes the value of a characteristic.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    /// Calls with type `CoreCharacteristicWriteType.withoutResponse` will be returned immediatly without success or failure check.
    ///
    /// Note: Concurrent writes to different characteristics is supported.
    /// - Throws: `BluetoothError.peripheralDisconnected` `.characteristicWriteFailed` `.operationTimedOut`
    func writeValue(_ data: Data, for characteristic: CoreCharacteristic, type: CoreCharacteristicWriteType) async throws {
        try await perform {
            try await context.writeCharacteristicValueExecutor.enqueue(withKey: characteristic.uuid, timeout: bluetoothApiTimeout) { [weak self, peripheral] in
                guard let self else { return }

                guard peripheral.state == .connected else {
                    try? await self.context.writeCharacteristicValueExecutor.setWorkCompletedForKey(characteristic.uuid, result: .failure(BluetoothError.peripheralDisconnected(self.identifier, nil)))
                    return
                }

                let supportsWriteWithoutResponse = characteristic.properties.contains(.writeWithoutResponse)
                // set characteristic write type based on supported write type
                if supportsWriteWithoutResponse, type == .withoutResponse {
                    peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                } else {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }

                // Set response based on requested write type.
                if type == .withoutResponse {
                    try? await self.context.writeCharacteristicValueExecutor.setWorkCompletedForKey(characteristic.uuid, result: .success(()))
                }
            }
        }
    }

    /// Sets notifications or indications for the value of a specified characteristic.
    /// This call is executed in async blocking fashion, that is, call will not return until timeout or peripheral delegate gets called.
    ///
    /// Note: Concurrent set notify for different characteristics is supported.
    /// - Throws: `BluetoothError.peripheralDisconnected` `.characteristicSetNotifyValueFailed` `.operationTimedOut`
    func setNotifyValue(_ enabled: Bool, for characteristic: CoreCharacteristic) async throws {
        try await perform {
            try await context.setNotifyValueExecutor.enqueue(withKey: characteristic.uuid, timeout: bluetoothApiTimeout) { [weak self] in
                guard let self else { return }
                guard self.peripheral.state == .connected else {
                    try? await self.context.setNotifyValueExecutor.setWorkCompletedForKey(characteristic.uuid, result: .failure(BluetoothError.peripheralDisconnected(self.identifier, nil)))
                    return
                }

                self.peripheral.setNotifyValue(enabled, for: characteristic)
            }
        }
    }

    /// Stream of characteristic notification when any notifying characteristic has been changed.
    /// - returns: AsyncStream emitting `CoreCharacteristic` when given characteristic has been changed.
    var valueUpdateNotificationStream: AsyncStream<(CoreCharacteristic, Data?)> {
        get async {
            await context.characteristicValueUpdateStream
        }
    }

    // MARK: Initialization
    init(manager: BluetoothManaging,
         peripheral: CorePeripheralRepresentable,
         logger: NDLoggerProtocol?,
         timeout: TimeInterval = 5.0) {
        self.manager = manager
        self.peripheral = peripheral
        self.logger = logger
        self.bluetoothApiTimeout = timeout
        let delegateWrapper = BlePeripheralDelegateWrapper(logger: logger)
        self.context = BlePeripheralContext(delegateWrapper: delegateWrapper, logger: logger)
        self.peripheral.delegate = delegateWrapper
        publishPeripheralState()
        Task { [weak self] in
            await self?.setupSubscriptions()
        }
    }

    deinit {
        stateSubject.send(completion: .finished)
        cancellableTasks.forEach { $0.cancel() }
        cancellableTasks.removeAll()
    }

    // MARK: Private
    private func setupSubscriptions() async {
        await manager.connectionEventsStream.sink { [weak self] event in
            guard let self else { return }
            guard event.peripheralID == self.identifier else { return }
            logger?.logDebug("> \(String(describing: Swift.type(of: self))): connection event \(event)", tag: .ble)
            publishPeripheralState()
            switch event {
            case .didConnectPeripheral(peripheral: let peripheral):
                await self.didConnect(peripheral: peripheral)
            case .didFailToConnect(peripheral: let peripheral, error: let error):
                await self.didFailToConnect(peripheral: peripheral, error: error)
            case .didDisconnectPeripheral(peripheral: let peripheral, error: let error):
                await self.didDisconnectPeripheral(peripheral: peripheral, error: error)
            }
        }
        .store(in: &cancellableTasks)

        await manager.bluetoothState.sink { [weak self] /*state*/_ in
            self?.publishPeripheralState()
        }
        .store(in: &subscriptions)
    }

    private func publishPeripheralState() {
        stateSubject.send(peripheral.state)
    }

    private func cleanupOnDisconnect() async {
        await context.flush(error: BluetoothError.peripheralDisconnected(identifier, nil))
    }

    /// Performs an async throwing expression and throws `BluetoothError`.
    /// In case of other errors than BluetoothError and AsyncExecutorError.timeout,
    /// wraps it up in `BluetoothError.unknownError` error.
    /// - Parameter expression: The expression to execute
    /// - Throws: `BluetoothError`
    /// - Returns: The return value of the given expression
    private func perform<T>(_ expression: () async throws -> T) async throws -> T {
        do {
            return try await expression()
        } catch let bleError as BluetoothError {
            throw bleError
        } catch AsyncExecutorError.timeout {
            throw BluetoothError.operationTimedOut
        } catch {
            throw BluetoothError.unknownError(error.localizedDescription)
        }
    }

    private let manager: BluetoothManaging
    private let context: BlePeripheralContext
    private let logger: NDLoggerProtocol?
    private let bluetoothApiTimeout: TimeInterval
    private let stateSubject = PassthroughSubject<CorePeripheralState, Never>()
    nonisolated(unsafe) private var subscriptions = Set<AnyCancellable>()
    nonisolated(unsafe) private var cancellableTasks = Set<Task<Void, any Error>>()
}

// MARK: Bluetooth connection events handlers
extension BlePeripheral {

    private func didConnect(peripheral: CorePeripheralRepresentable) async {
        await context.connectToPeripheralExecutor.flush(.success(()))
    }

    private func didDisconnectPeripheral(peripheral: CorePeripheralRepresentable, error: Error?) async {
        await cleanupOnDisconnect()
    }

    private func didFailToConnect(peripheral: CorePeripheralRepresentable, error: Error?) async {
        do {
            let result = ResultUtils.result(for: (), error: error, resultingError: BluetoothError.peripheralConnectionFailed(peripheral.identifier, error))
            try await context.connectToPeripheralExecutor.setWorkCompletedWithResult(result)
        } catch {
            logger?.logInfo("Received onDidFailToConnect without a continuation! \(error)", tag: .ble)
        }
    }
}
