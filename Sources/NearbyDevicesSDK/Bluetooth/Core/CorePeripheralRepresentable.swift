//
//  CorePeripheralRepresentable.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

/// A remote peripheral device.
/// ``CorePeripheralRepresentable`` will proxy all requests to an underlying `CBPeripheral`.
protocol CorePeripheralRepresentable: NSObject, Sendable {

    /// Instance UUID.
    /// This identifies CBPeripheral instance. When CBPeripheral instance changes for a given PeripheralId, this objectId should change, but `identifier` should not change.
    var objectId: UUID { get }

    /// The UUID associated with the peer.
    var identifier: UUID { get }

    /// The delegate object specified to receive peripheral events.
    var delegate: CorePeripheralDelegate? { get set }

    /// The name of the peripheral.
    var name: String? { get }

    /// The connection state of the peripheral.
    ///
    /// This property represents the current connection state of the peripheral.
    var state: CorePeripheralState { get }

    /// A list of a peripheral’s discovered services.
    var services: [CoreService]? { get }

    /// A Boolean value that indicates whether the remote device can send a write without a response.
    var canSendWriteWithoutResponse: Bool { get }

    /// Retrieves the current RSSI value for the peripheral while connected to the central manager.
    func readRSSI()

    /// Discovers the specified services of the peripheral.
    /// - Parameter serviceUUIDs: A list of ``CBUUIDConvertible`` objects representing the service types to be
    ///                           discovered. If `nil` or an empty array, all services will be discovered.
    func discoverServices(_ serviceUUIDs: [CoreUUID]?)

    /// Discovers the specified characteristics of a service.
    /// - Parameters:
    ///   - characteristicUUIDs: A list of ``CBUUIDConvertible`` objects representing the characteristic types
    ///                          to be discovered. If `nil` or an empty array, all characteristics of service will be discovered.
    ///   - service: A GATT service.
    func discoverCharacteristics(_ characteristicUUIDs: [CoreUUID]?, for service: CoreService)

    /// Retrieves the value of a specified characteristic.
    ///
    /// When you call this method to read the value of a characteristic, the peripheral calls the
    /// ``CorePeripheralDelegate/didUpdateValueFor``
    /// method of its delegate object. If the peripheral successfully reads the value of the characteristic, you can access it
    /// through the characteristic’s ``CoreCharacteristic/value`` property.
    /// - Parameter characteristic: A GATT characteristic.
    func readValue(for characteristic: CoreCharacteristic)

    /// The maximum amount of data, in bytes, you can send to a characteristic in a single write type.
    /// - Parameter type: The characteristic write type to inspect.
    func maximumWriteValueLength(for type: CoreCharacteristicWriteType) -> Int

    /// Writes the value of a characteristic.
    ///
    /// When you call this method to write the value of a characteristic, the peripheral calls the
    /// ``CorePeripheralDelegate/didWriteValueFor:characteristic:error:``
    /// method of its delegate object only if you specified the write type as `.withResponse`. The response you
    /// receive through the ``CorePeripheralDelegate/didWriteValueFor:characteristic:error:``
    /// delegate method indicates whether the write was successful; if the write failed, it details the cause of the failure in an error.
    /// - Parameters:
    ///   - data: The value to write.
    ///   - characteristic: The characteristic containing the value to write.
    ///   - type: The type of write to execute. For a list of the possible types of writes to a characteristic’s value, see
    ///           ``CoreCharacteristicWriteType``.
    func writeValue(_ data: Data, for characteristic: CoreCharacteristic, type: CoreCharacteristicWriteType)

    /// Sets notifications or indications for the value of a specified characteristic.
    ///
    /// When you enable notifications for the characteristic’s value, the peripheral calls the
    /// ``CorePeripheralDelegate/didUpdateNotificationStateFor:characteristic:error:`` method
    /// of its delegate object to indicate if the action succeeded.
    /// - Parameters:
    ///   - enabled: Boolean value that indicates whether to receive notifications or indications whenever the
    ///              characteristic’s value changes. true if you want to enable notifications or indications for the
    ///              characteristic’s value. false if you don’t want to receive notifications or indications whenever the
    ///              characteristic’s value changes.
    ///   - characteristic: The specified characteristic.
    func setNotifyValue(_ enabled: Bool, for characteristic: CoreCharacteristic)
}

/// A protocol that provides updates on the use of a peripheral’s services.
protocol CorePeripheralDelegate: AnyObject {
    /// This method returns the result of a ``CorePeripheralRepresentable/readRSSI()`` call.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this update.
    ///   - RSSI: The current RSSI of the link.
    ///   - error: If an error occurred, the cause of the failure.
    func didReadRSSI(_ peripheral: CorePeripheralRepresentable, RSSI: NSNumber, error: Error?)

    /// This method returns the result of a ``CorePeripheralRepresentable/discoverServices(_:)`` call.
    /// If the service(s) were read successfully, they can be retrieved via peripheral's services property.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this information.
    ///   - error: If an error occurred, the cause of the failure.
    func didDiscoverServices(_ peripheral: CorePeripheralRepresentable, error: Error?)

    /// This method returns the result of a ``CorePeripheralRepresentable/discoverCharacteristics(_:for:)`` call.
    /// If the characteristic(s) were read successfully, they can be retrieved via service's ``CoreService/characteristics`` property.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this information.
    ///   - service: The ``CBService`` object containing the characteristic(s).
    ///   - error: If an error occurred, the cause of the failure.
    func didDiscoverCharacteristicsFor(_ peripheral: CorePeripheralRepresentable, service: CoreService, error: Error?)

    /// This method returns the result of a ``CorePeripheralRepresentable/setNotifyValue(_:for:)`` call.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this information.
    ///   - characteristic: A ``CoreCharacteristic`` object.
    ///   - error: If an error occurred, the cause of the failure.
    func didUpdateNotificationStateFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?)

    /// This method is invoked after a ``CorePeripheralRepresentable/readValue(for:)`` call, or upon receipt of a notification/indication.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this information.
    ///   - characteristic: A ``CoreCharacteristic`` object.
    ///   - error: If an error occurred, the cause of the failure.
    func didUpdateValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?)

    /// This method returns the result of a ``CorePeripheralRepresentable/writeValue(_:for:type:)`` call, when the `.withResponse` type is used.
    /// - Parameters:
    ///   - peripheral: The peripheral providing this information.
    ///   - characteristic: A ``CoreCharacteristic`` object.
    ///   - error: If an error occurred, the cause of the failure.
    func didWriteValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?)
}
