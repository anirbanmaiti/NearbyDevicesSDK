//
//  BluetoothError.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import CoreBluetooth
import Foundation

/// Errors used by Nearby Device bluetooth layer.
public enum BluetoothError: LocalizedError {

    /// Emitted when bluetooth stack is not initialized. You have to call `BluetoothManager.setup`
    case bluetoothManagerUnavailable

    // States
    /// Emitted when Bluetooth state is `unsupported`
    case bluetoothUnsupported
    /// Emitted when Bluetooth state is `unauthorized`
    case bluetoothUnauthorized
    /// Emitted when Bluetooth state is `poweredOff`
    case bluetoothPoweredOff

    // Peripheral
    /// Emitted when corresponding peripheral not found in CBManager.
    case peripheralNotFound
    /// Emitted when peripheral connection attempt fails.
    case peripheralConnectionFailed(_ identifier: UUID, _ error: Error?)
    /// Emitted when peripheral gets disconnected.
    case peripheralDisconnected(_ identifier: UUID, _ error: Error?)
    /// Emitted when central manager fails to read peripheral RSSI value.
    case peripheralRSSIReadFailed(_ identifier: UUID, _ error: Error?)

    /// Emitted when peripheral connection is not established.
    case peripheralConnectionNotReady

    // Services
    /// Emits when services discovery error has occured.
    case servicesDiscoveryFailed(_ identifier: UUID, _ error: Error?)

    // Characteristics
    /// Emits when characteristics discovery error has occured.
    case characteristicsDiscoveryFailed(_ identifier: CoreUUID, _ error: Error?)
    /// Emits when characteristics write error has occured.
    case characteristicWriteFailed(_ identifier: CoreUUID, _ error: Error?)
    /// Emits when characteristics read error has occured.
    case characteristicReadFailed(_ identifier: CoreUUID, _ error: Error?)
    /// Emits when characteristics isNotyfing value change error has occured
    case characteristicSetNotifyValueFailed(_ identifier: CoreUUID, _ error: Error?)

    // Emitted when an asynchronous operation timed out.
    case operationTimedOut

    // Emitted when an error outside BluetoothError is encountered.
    case unknownError(String)

    /// Human readable description of bluetooth error
    public var errorDescription: String? {
        switch self {
            case .bluetoothManagerUnavailable:
                return "The bluetooth stack is not initialzed or been destroyed. Make sure to call `setup`"
            case .bluetoothUnsupported:
                return "Bluetooth is unsupported"
            case .bluetoothUnauthorized:
                return "Bluetooth is unauthorized"
            case .bluetoothPoweredOff:
                return "Bluetooth is powered off"
            case .peripheralNotFound:
                return "Bluetooth peripheral not found. Likely not discovered or destroyed by bluetooth stack."
            case let .peripheralConnectionFailed(_, err):
                return "Connection error has occured: \(err?.localizedDescription ?? "-")"
            case let .peripheralDisconnected(_, err):
                return "Connection drop has occured: \(err?.localizedDescription ?? "-")"
            case let .peripheralRSSIReadFailed(_, err):
                return "RSSI read failed : \(err?.localizedDescription ?? "-")"
            case .peripheralConnectionNotReady:
                return "Peripheral connection is not ready."
            case let .servicesDiscoveryFailed(_, err):
                return "Services discovery error has occured: \(err?.localizedDescription ?? "-")"
            case let .characteristicsDiscoveryFailed(_, err):
                return "Characteristics discovery error has occured: \(err?.localizedDescription ?? "-")"
            case let .characteristicWriteFailed(_, err):
                return "Characteristic write error has occured: \(err?.localizedDescription ?? "-")"
            case let .characteristicReadFailed(_, err):
                return "Characteristic read error has occured: \(err?.localizedDescription ?? "-")"
            case let .characteristicSetNotifyValueFailed(_, err):
                return "Characteristic isNotyfing value change error has occured: \(err?.localizedDescription ?? "-")"
            case .operationTimedOut:
                return "Requested operation timed out."
            case let .unknownError(description):
                return "Unknown error : \(description)"
        }
    }

    /// The domain of the error.
    public static var errorDomain: String {
        return "com.itiam.nearbydevices.bluetooth"
    }
}
extension BluetoothError: Equatable {
    public static func == (lhs: BluetoothError, rhs: BluetoothError) -> Bool {
        switch (lhs, rhs) {
            case (.bluetoothManagerUnavailable, .bluetoothManagerUnavailable),
                (.bluetoothUnsupported, .bluetoothUnsupported),
                (.bluetoothUnauthorized, .bluetoothUnauthorized),
                (.bluetoothPoweredOff, .bluetoothPoweredOff),
                (.peripheralNotFound, .peripheralNotFound),
                (.peripheralConnectionNotReady, .peripheralConnectionNotReady),
                (.operationTimedOut, .operationTimedOut): return true

            case let (.peripheralConnectionFailed(l, _), .peripheralConnectionFailed(r, _)),
                let (.peripheralDisconnected(l, _), .peripheralDisconnected(r, _)),
                let (.peripheralRSSIReadFailed(l, _), .peripheralRSSIReadFailed(r, _)),
                let (.servicesDiscoveryFailed(l, _), .servicesDiscoveryFailed(r, _)): return l == r

            case let (.characteristicsDiscoveryFailed(l, _), .characteristicsDiscoveryFailed(r, _)),
                let (.characteristicWriteFailed(l, _), .characteristicWriteFailed(r, _)),
                let (.characteristicReadFailed(l, _), .characteristicReadFailed(r, _)),
                let (.characteristicSetNotifyValueFailed(l, _), .characteristicSetNotifyValueFailed(r, _)): return l == r

            default: return false
        }
    }
}

extension BluetoothError {
    init(state: BluetoothState) {
        switch state {
        case .unsupported:
            self = .bluetoothUnsupported
        case .unauthorized:
            self = .bluetoothUnauthorized
        case .poweredOff:
            self = .bluetoothPoweredOff
        default:
            self = .bluetoothManagerUnavailable
        }
    }
}
