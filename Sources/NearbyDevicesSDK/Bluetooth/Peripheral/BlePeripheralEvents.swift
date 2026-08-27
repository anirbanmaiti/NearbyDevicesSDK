//
//  BlePeripheralEvents.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// Events published by peripheral.
enum BlePeripheralEvent: Sendable {
    case didReadRSSI(CorePeripheralRepresentable, Int, Error?)
    case didDiscoverServices(CorePeripheralRepresentable, Error?)
    case didDiscoverCharacteristicsForService(CorePeripheralRepresentable, CoreService, Error?)
    case didUpdateValueForCharacteristic(CorePeripheralRepresentable, CoreCharacteristic, Data?, Error?)
    case didWriteValueForCharacteristic(CorePeripheralRepresentable, CoreCharacteristic, Error?)
    case didUpdateNotificationStateForCharacteristic(CorePeripheralRepresentable, CoreCharacteristic, Error?)
}
