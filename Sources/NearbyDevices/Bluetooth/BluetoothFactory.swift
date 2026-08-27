//
//  BluetoothFactory.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Bluetooth factory to create `CoreCentralManager`
protocol BluetoothCreating: AnyObject, Sendable {
    /// Instantiates CBCentralManager and injects to CoreCentralManager. This should be called from CentralManager
    func makeCoreCentralManager(delegate: CoreCentralManagerDelegate?, dispatcher: DispatchQueue?, config: BluetoothManagerConfiguration) -> CoreCentralManaging
}

extension NearbyDevicesGate: BluetoothCreating {

    func makeCoreCentralManager(delegate: CoreCentralManagerDelegate?, dispatcher: DispatchQueue?, config: BluetoothManagerConfiguration) -> CoreCentralManaging {
        return CoreCentralManager(
            dispatcher: dispatcher,
            delegate: delegate,
            bluetoothConfiguration: config,
            logger: logger
        )
    }
}

/// Builds `BluetoothManager`
extension NearbyDevicesGate {
    func makeBluetoothManager() -> BluetoothManaging {
        return BluetoothManager(factory: self, dispatcher: DispatchQueue.bluetoothQueue, logger: logger)
    }
}

internal extension DispatchQueue {
    static let bluetoothQueue: DispatchQueue = DispatchQueue(label: "com.itiam.nd.bluetoothqueue", qos: .utility)
}
