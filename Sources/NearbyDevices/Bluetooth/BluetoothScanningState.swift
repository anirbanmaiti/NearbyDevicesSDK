//
//  BluetoothScanningState.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Represents Bluetooth scanning states
enum BluetoothScanningState: Equatable, Sendable {

    /// Idle bluetooth scanning state.
    case idle

    /// bluetooth scanning state triggered by corresponding `PeripheralScanRequest`
    case scanning(_ request: PeripheralScanRequest)

    /// Boolean representing if bluetooth scanning in enabled.
    var isScanning: Bool {
        if case .scanning = self {
            return true
        }
        return false
    }
}
