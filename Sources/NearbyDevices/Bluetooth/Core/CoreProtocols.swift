//
//  CoreProtocols.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import CoreBluetooth

/// `CoreService` represent services of a remote peripheral. Services are either primary or secondary and
/// may contain multiple characteristics or included services (references to other services).
protocol CoreService: AnyObject, Sendable {
    /// The Bluetooth UUID of the service.
    var uuid: CoreUUID { get }

    /// A list of characteristics that have so far been discovered in this service.
    var cbcharacteristics: [CoreCharacteristic]? { get }
}

extension CBService: CoreService {

    var cbcharacteristics: [CoreCharacteristic]? {
        characteristics
    }
}

/// `CoreCharacteristic` represents further information about a peripheral’s service. In particular,
/// represent the characteristics of a remote peripheral’s service. A characteristic contains a single value and any number
/// of descriptors describing that value. The properties of a characteristic determine how you can use a characteristic’s value,
/// and how you access the descriptors.
protocol CoreCharacteristic: AnyObject, Sendable {
    var uuid: CoreUUID { get }

    /// A back-pointer to the service this characteristic belongs to.
    var cbservice: CoreService? { get }

    /// The properties of the characteristic.
    var properties: CoreCharacteristicProperties { get }

    /// The value of the characteristic.
    var value: Data? { get }

    /// Whether the characteristic is currently notifying or not.
    var isNotifying: Bool { get }
}

extension CBCharacteristic: CoreCharacteristic {
    var cbservice: CoreService? {
        service
    }
}
