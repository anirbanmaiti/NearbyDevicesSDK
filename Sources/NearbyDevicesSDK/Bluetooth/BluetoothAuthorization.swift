//
//  BluetoothAuthorization.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// The possible authorization states of a Core Bluetooth manager.
public enum BluetoothAuthorization: Int, Sendable {

    /// User has not yet made a choice with regards to this application.
    case notDetermined

    /// This application is not authorized to share data while backgrounded. The user cannot change this application’s status, possibly due to active restrictions such as parental controls being in place.
    case restricted

    /// User has explicitly denied this application from sharing data while backgrounded.
    case denied

    /// User has authorized this application to share data while backgrounded.
    case allowedAlways

    init(_ authorization: CoreManagerAuthorization) {
        switch authorization {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .allowedAlways:
            self = .allowedAlways
        @unknown default:
            fatalError("Unhandled CBCentralManager authorization: \(authorization.rawValue).")
        }
    }

    static func current() -> BluetoothAuthorization {
        return BluetoothAuthorization(CoreCentralManager.authorization)
    }
}

extension BluetoothAuthorization {
    public var statusString: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .allowedAlways:
            return "allowedAlways"
        }
    }
}
