//
//  PeripheralDiscoveryEvent.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Represents a peripheral discovery event
struct PeripheralDiscoveryEvent: Sendable {

    /// Peripheral identifier.
    let identifier: UUID
    
    /// Object containing any advertisement and scan response data.
    let advertisement: Advertisement

    // MARK: Initialization
    init(identifier: UUID, advertisement: Advertisement) {
        self.identifier = identifier
        self.advertisement = advertisement
    }

    init(identifier: UUID, name: String?, advertisementData: [String: Any], rssi: Int?) {
        self.init(
            identifier: identifier,
            advertisement: Advertisement(
                advertisementData: advertisementData,
                name: name,
                rssi: rssi
            )
        )
    }
}

// MARK: - CustomStringConvertible
extension PeripheralDiscoveryEvent: CustomStringConvertible {
    public var description: String {
        "\(identifier) \(advertisement)"
    }
}

// MARK: - Hashable
extension PeripheralDiscoveryEvent: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
