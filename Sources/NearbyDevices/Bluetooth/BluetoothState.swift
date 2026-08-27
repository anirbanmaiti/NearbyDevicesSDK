//
//  BluetoothState.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// The possible states of a Core Bluetooth manager.
public enum BluetoothState: Int, Sendable {
    /// The manager’s state is unknown.
    case unknown
    /// A state that indicates the connection with the system service was momentarily lost.
    case resetting
    /// A state that indicates this device doesn’t support the Bluetooth low energy central or client role.
    case unsupported
    /// A state that indicates the application isn’t authorized to use the Bluetooth low energy role.
    case unauthorized
    /// A state that indicates Bluetooth is currently powered off.
    case poweredOff
    /// A state that indicates Bluetooth is currently powered on and available to use.
    case poweredOn

    init(_ state: CoreManagerState) {
        switch state {
        case .unsupported:
            self = .unsupported
        case .unauthorized:
            self = .unauthorized
        case .poweredOff:
            self = .poweredOff
        case .poweredOn:
            self = .poweredOn
        case .unknown:
            self = .unknown
        case .resetting:
            self = .resetting
        @unknown default:
            fatalError("Unhandled CBCentralManager state: \(state.rawValue).")
        }
    }
}

extension BluetoothState {
    public var statusString: String {
        switch self {
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        case .unauthorized:
            return "unauthorized"
        case .unknown:
            return "unknown"
        case .unsupported:
            return "unsupported"
        case .resetting:
            return "resetting"
        }
    }
}

extension BluetoothState {
    /// Whether Bluetooth is ready to be used or not given a bluetoothState.
    /// - Returns:
    ///     success when `poweredOn`; failure when `unsupported`, `unauthorized` or `poweredOff`; and
    ///     nil for `unknown` or `resetting`.
    func isBluetoothReady() -> Result<Void, Error>? {
        guard let isReady: Bool = isReady else {
            return nil
        }
        return isReady
            ? .success(())
        : .failure(BluetoothError(state: self))
    }

    /// Whether Bluetooth is ready to be used or not given a bluetoothState.
    /// - Returns:
    ///     true when `poweredOn`; false when `unsupported`, `unauthorized` or `poweredOff`; and
    ///     nil for `unknown` or `resetting`.
    var isReady: Bool? {
        switch self {
        case .poweredOn:
            return true
        case .unsupported, .unauthorized, .poweredOff:
            return false
        case .unknown, .resetting:
            return nil
        }
    }
}
