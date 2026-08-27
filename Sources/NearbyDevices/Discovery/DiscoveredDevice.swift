//
//  DiscoveredDevice.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// Represents discovered device with or without DeviceID
public struct DiscoveredDevice: Hashable, Sendable {

    /// The peripheral identifier.
    public let peripheralIdentifier: UUID
    
    /// The Advertised data of the device that has been discovered nearby.
    public let advertisement: Advertisement

    /// The timestamp when the `DiscoveredDevice` was last updated
    public var lastUpdated: Date

    /// The connection state of the device
    public var isConnected: Bool

    // MARK: Initialization
    public init(
        peripheralIdentifier: UUID,
        advertisement: Advertisement,
        lastUpdated: Date? = nil,
        isConnected: Bool = false,
    ) {
        self.peripheralIdentifier = peripheralIdentifier
        self.advertisement = advertisement
        self.isConnected = isConnected
        self.lastUpdated = lastUpdated ?? advertisement.timestamp
    }

    internal init(peripheralIdentifier: UUID, advertisement: Advertisement) {
        self.init(
            peripheralIdentifier: peripheralIdentifier,
            advertisement: advertisement,
            lastUpdated: advertisement.timestamp,
            isConnected: false
        )
    }

    internal init(
        event: PeripheralDiscoveryEvent
    ) {
        self.init(
            peripheralIdentifier: event.identifier,
            advertisement: event.advertisement,
            lastUpdated: event.advertisement.timestamp
        )
    }

    mutating func updateConnected(_ isConnected: Bool) {
        self.isConnected = isConnected
        self.lastUpdated = .now
    }
}

// MARK: - CustomStringConvertible
extension DiscoveredDevice: CustomStringConvertible {
    public var description: String {
        let descriptionComponents = [
            "id=\(peripheralIdentifier.uuidString)",
            "connected=\(isConnected)",
            "lastUpdated=\(String(describing: lastUpdated))",
            "<\(advertisement.description)>"
        ]
        let description = descriptionComponents.joined(separator: " ")
        return "<\(description)>"
    }
}
