//
//  CoreTypes.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import CoreBluetooth

/// A universally unique identifier, as defined by Bluetooth standards.
/// Instances of the `CoreUUID` class represent the 128-bit universally unique identifiers (UUIDs)
public typealias CoreUUID = CBUUID

// `CBUUID` is an immutable value (NSCopying), safe to share across concurrency domains.
extension CBUUID: @retroactive @unchecked Sendable {}

/// The possible states of a Core Bluetooth manager.
public typealias CoreManagerState = CBManagerState

/// The possible states of a Core Bluetooth manager authorization.
typealias CoreManagerAuthorization = CBManagerAuthorization

/// Values representing the connection state of a peripheral.
typealias CorePeripheralState = CBPeripheralState

/// A Boolean value that specifies whether the scan should run without duplicate filtering.
let CoreCentralManagerScanOptionAllowDuplicatesKey = CBCentralManagerScanOptionAllowDuplicatesKey

/// An array of service UUIDs.
let CoreAdvertisementDataServiceUUIDsKey = CBAdvertisementDataServiceUUIDsKey

/// Values representing the possible write types to a characteristic’s value.
typealias CoreCharacteristicWriteType = CBCharacteristicWriteType

/// Values that represent the possible properties of a characteristic.
typealias CoreCharacteristicProperties = CBCharacteristicProperties
