//
//  BluetoothManagerEvents.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Connection events published by central manager
enum PeripheralConnectionEvent: Sendable {

    /// Emitted when the central manager connects to a peripheral.
    case didConnectPeripheral(peripheral: CorePeripheralRepresentable)

    /// Emitted whenever the central manager disconnected from a peripheral.
    case didDisconnectPeripheral(peripheral: CorePeripheralRepresentable, error: Error?)

    /// Emitted when the central manager failed to create a connection with a peripheral.
    case didFailToConnect(peripheral: CorePeripheralRepresentable, error: Error?)

    /// Peripheral ID associated with the connection event.
    var peripheralID: UUID {
        switch self {
        case .didConnectPeripheral(peripheral: let peripheral):
            return peripheral.identifier
        case .didDisconnectPeripheral(peripheral: let peripheral, error: _):
            return peripheral.identifier
        case .didFailToConnect(peripheral: let peripheral, error: _):
            return peripheral.identifier
        }
    }
}

/// State and discovery events published by central manager
enum BluetoothManagerEvent: Sendable {

    /// Emitted when the central manager state changes.
    case didUpdateState(state: BluetoothState)

    /// Emitted on peripheral discovery.
    case didDiscover(event: PeripheralDiscoveryEvent)

//    /// The state of the central manager at the time of app termination by system
//    case willRestoreState(_ state: CentralRestorationState)
}
