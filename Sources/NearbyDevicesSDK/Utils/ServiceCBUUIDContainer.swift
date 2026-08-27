//
//  ServiceCBUUIDContainer.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import CoreBluetooth
import Foundation

enum ServiceCBUUIDContainer {
    nonisolated(unsafe) static let unactivated: CoreUUID = .unactivated
    nonisolated(unsafe) static let activated: CoreUUID = .activated
    nonisolated(unsafe) static let bose: CoreUUID = .bose

    static var all: Set<CoreUUID> {
        Set([ServiceCBUUIDContainer.unactivated, ServiceCBUUIDContainer.activated, ServiceCBUUIDContainer.bose])
    }

    public var operable: Set<CoreUUID> {
        Set([ServiceCBUUIDContainer.activated, ServiceCBUUIDContainer.bose])
    }
}

extension CoreUUID {
    nonisolated(unsafe) static let unactivated = CoreUUID(string: .unactivated)
    nonisolated(unsafe) static let activated = CoreUUID(string: .activated)
    nonisolated(unsafe) static let bose = CoreUUID(string: .bose)
    nonisolated(unsafe) static let hubble = CoreUUID(string: .hubble)
}

extension String {
    static let unactivated = "FEEC"
    static let activated = "FEED"
    static let bose = "FEBE"
    static let hubble = "FCA6"
}
