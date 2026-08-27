//
//  CoreCentralManaging.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

/// A bluetooth manager that scans for, discovers, connects to, and manages peripherals.
/// ``CoreCentralManager`` will proxy all requests to an underlying `CBCentralManager`.
protocol CoreCentralManaging: AnyObject {

    /// Whether or not the manager is scanning for peripherals.
    var isScanning: Bool { get }

    /// Stream of whether or not central manager is scanning.
    var isScanningPublisher: AnyPublisher<Bool, Never> { get }

    /// The current state of the manager.
    var state: CoreManagerState { get }

    /// The delegate object that will receive central events.
    var delegate: CoreCentralManagerDelegate? { get set }

    /// Starts scanning for peripherals that are advertising any of the services listed in serviceUUIDs.
    ///
    /// Although strongly discouraged, if serviceUUIDs is nil all discovered peripherals will be returned. If the central is already scanning with different serviceUUIDs or options,
    /// the provided parameters will replace them. Applications that have specified the bluetooth-central background mode are allowed to scan while backgrounded, with two caveats:
    /// the scan must specify one or more service types in serviceUUIDs, and the CBCentralManagerScanOptionAllowDuplicatesKey scan option will be ignored.
    /// - Parameters:
    ///   - serviceUUIDs: A list of <code>CBUUIDConvertible</code> objects representing the service(s) to scan for.
    ///   - options: An optional dictionary specifying options for the scan.
    func scanForPeripherals(withServices serviceUUIDs: [CoreUUID]?, options: [String: Any]?)

    /// Stops scanning for peripherals.
    func stopScan()

    /// Establishes a local connection to a peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral to which the central is attempting to connect.
    ///   - options: A dictionary to customize the behavior of the connection
    ///
    ///   Note: Attempts to connect to a peripheral don’t time out. To explicitly cancel a pending connection to a peripheral,
    ///   call the `cancelPeripheralConnection(_:)` method
    /// - Throws: `BluetoothError.peripheralNotFound`
    func connect(_ peripheral: CorePeripheralRepresentable, options: [String: Any]?) throws

    /// Cancels an active or pending local connection to a peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral to which the central manager is either trying to connect or has already connected.
    /// - Throws: `BluetoothError.peripheralNotFound`
    func cancelPeripheralConnection(_ peripheral: CorePeripheralRepresentable) throws

    /// Attempts to retrieve the CBPeripheral object(s) with the corresponding identifiers.
    ///
    /// - Parameters:
    ///   - identifiers: A list of peripheral identifiers.
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CorePeripheralRepresentable]

    /// Retrieves all peripherals that are connected to the system and implement any of the services listed in <i>serviceUUIDs</i>.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: List of serviceUUIDs
    /// - Returns: A list of <code>CBPeripheral</code> objects.
   func retrieveConnectedPeripherals(withServices serviceUUIDs: [CoreUUID]) -> [CorePeripheralRepresentable]
}

// MARK: - CoreCentralManagerDelegate

/// Delegate for BlePeripheralManager.
protocol CoreCentralManagerDelegate: AnyObject {

    ///  Invoked whenever the central manager's state has been updated.
    ///
    ///  Commands should only be issued when the state is CBCentralManagerStatePoweredOn. A state below CBCentralManagerStatePoweredOn.
    ///  implies that scanning has stopped and any connected peripherals have been disconnected. If the state moves below CBCentralManagerStatePoweredOff, all CBPeripheral objects obtained from this central manager become invalid and must be retrieved or discovered again.
    func didUpdateState(central: CoreCentralManaging)

    /// This method is invoked while scanning, upon the discovery of peripheral by central.
    ///
    /// A discovered peripheral must be retained in order to use it; otherwise, it is assumed to not be of interest and will be cleaned up by the central manager.
    /// - Parameters:
    ///   - peripheral: A Peripheral object.
    ///   - advertisementData: advertised data
    ///   - rssi: advertisement rssi
    func didDiscover(peripheral: CorePeripheralRepresentable, advertisementData: [String: Any], rssi RSSI: Int?)

    /// Invoked whenever the central manager connected to a peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: A CorePeripheralRepresentable object.
    func didConnect(peripheral: CorePeripheralRepresentable)

    /// Invoked whenever the central manager disconnected from a peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: The now-disconnected peripheral.
    ///   - error: The cause of the failure, or nil if no error occurred.
    func didDisconnectPeripheral(peripheral: CorePeripheralRepresentable, error: Error?)

    /// Invoked when the central manager failed to create a connection with a peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral that failed to connect.
    ///   - error: The cause of the failure, or nil if no error occurred.
    func didFailToConnect(peripheral: CorePeripheralRepresentable, error: Error?)

}
