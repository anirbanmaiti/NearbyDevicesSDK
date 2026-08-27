//
//  PeripheralState.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

enum PeripheralState: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
    case disconnecting = 3

    init(_ state: CorePeripheralState) {
        switch state {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            fatalError("Unhandled CBPeripheralState state: \(state.rawValue).")
        }
    }
}

extension PeripheralState {
    public var statusString: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .disconnecting:
            return "disconnecting"
        }
    }
}
