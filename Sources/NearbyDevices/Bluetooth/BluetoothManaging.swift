//
//  BluetoothManaging.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

typealias PeripheralID = UUID

// MARK: - BluetoothStateObservable - Central manager state observer
protocol BluetoothStateObservable: Sendable {

    /// Wait for Bluetooth stack to bootup and ensure that state is poweredOn else throws BluetoothError.
    /// - throws: `BluetoothError`
    func ensurePoweredOn() async throws

    /// Bluetooth authorization state.
    var authorization: CurrentValueStream<BluetoothAuthorization> { get async }

    /// Bluetooth central state stream.
    var bluetoothState: CurrentValueStream<BluetoothState> { get async }
}

// MARK: Bluetooth Scan Management
/// Manages peripheral discovery
protocol BluetoothScanManaging: Sendable {

    /// Central manager scanning state.
    var scanningState: BluetoothScanningState { get async }

    /// Central manager scanning state stream.
    var scanningStateStream: AsyncStream<BluetoothScanningState> { get async }

    /// Scan results stream.
    var scanResultStream: AsyncStream<PeripheralDiscoveryEvent> { get async }

    ///   Scans for Peripherals
    /// - Parameter request: Scan request containing set of scan request reason. ServiceUUIDs are calculated from `PeripheralScanRequest.scanReasons`
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    /// `BluetoothError.bluetoothPoweredOff`
    /// `BluetoothError.bluetoothUnsupported`
    /// `BluetoothError.bluetoothUnauthorized`
    func scanForPeripherals(with request: PeripheralScanRequest) async throws

    /// Stops peripheral scan
    /// Will stop the current scan through a CBCentralManager stopScan() function call and `scanningState` publisher
    /// will be call with `notScanning` state containing an error if something went wrong.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func stopPeripheralScan() async throws
}

// MARK: Peripheral's Connection Management
protocol BluetoothConnectionManaging: Sendable {

    /// Central Manager connection event stream.
    var connectionEventsStream: AsyncStream<PeripheralConnectionEvent> { get async }

    /// Returns list of `CorePeripheralRepresentable`s by their identifiers which are known to `CentralManager`.
    /// - Parameter identifiers: List of `CorePeripheralRepresentable`'s identifiers which should be retrieved.
    /// - Returns: Retrieved `CorePeripheralRepresentable`s.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) async throws -> [CorePeripheralRepresentable]

    /// Returns list of the `CorePeripheralRepresentable`s which are restored by the `CentralManager`
    /// - Returns: Retrieved Peripheral's identifiers that are restored
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func retrieveRestoredPeripheralsIDs() async throws -> [UUID]

    /// Returns list of the `CorePeripheralRepresentable`s which are currently connected to the `CentralManager`
    /// - Returns: Retrieved `CorePeripheralRepresentable`s. They are in connected state
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func retrieveConnectedPeripherals() async throws -> [CorePeripheralRepresentable]

    /// Establishes a local connection to a peripheral.
    ///
    /// After successfully establishing a local connection to a peripheral, the central manager object posts the
    /// `PeripheralConnectionEvent.didConnectPeripheral` event. If the connection attempt fails, the
    /// central manager object posts the `PeripheralConnectionEvent/didFailToConnect` event instead.
    /// Attempts to connect to a peripheral don’t time out.
    /// To explicitly cancel a pending connection to a peripheral, call the `cancelPeripheralConnection(_:)` method.
    /// - Parameter peripheral: The peripheral to which the central is attempting to connect.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    /// `BluetoothError.bluetoothPoweredOff`
    /// `BluetoothError.bluetoothUnsupported`
    /// `BluetoothError.bluetoothUnauthorized`
    func connect(peripheral: CorePeripheralRepresentable) async throws

    /// Cancels an active or pending local connection to a peripheral.
    /// Any `CorePeripheralRepresentable` class commands that are still pending to peripheral may not complete.
    /// Central manager object posts the`PeripheralConnectionEvent.didDisconnectPeripheral` event when peripheral is disconnected.
    /// - Parameter peripheral: The peripheral to which the central manager
    ///                         is either trying to connect or has already connected.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func cancelPeripheralConnection(peripheral: CorePeripheralRepresentable) async throws
}

// MARK: - BluetoothManager Management
protocol BluetoothManaging: BluetoothStateObservable, BluetoothScanManaging, BluetoothConnectionManaging {

    /// Initializes CBCentralManager and initial states.
    func initializeBluetooth(config: BluetoothManagerConfiguration) async
}

struct BluetoothManagerConfiguration {
    let restorationEnabled: Bool
}
