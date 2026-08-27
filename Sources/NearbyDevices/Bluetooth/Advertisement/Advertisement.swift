//
//  Advertisement.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import CoreBluetooth

public struct Advertisement: Sendable {
    public typealias ServiceData = [CBUUID: Data]

    /// Device name.
    public let name: String
    
    /// The current RSSI of a peripheral in dBm.
    public let rssi: Int?

    /// The time at which the peripheral was discovered.
    public let timestamp: Date

    /// A list of one or more service identifiers.
    public let serviceUUIDs: Set<String>

    /// A dictionary containing service-specific advertisement data keyed by serviceUUID.
    public let serviceData: ServiceData?

    /// Advertised manufacturer data.
    public let manufacturerData: Data?

    /// A dictionary containing any advertisement and scan response data.
    /// Note: Exposed publicly since TAP is using this.
    public nonisolated(unsafe) let advertisementData: [String: Any]

    // MARK: Initialization

    public init(
        name: String,
        advertisementData: [String: Any],
        serviceUUIDs: Set<CBUUID>,
        serviceData: ServiceData?,
        manufacturerData: Data?,
        rssi: Int?,
        timestamp: Date
    ) {
        self.name = name
        self.advertisementData = advertisementData
        self.rssi = rssi
        self.timestamp = timestamp
        self.serviceUUIDs = Set(serviceUUIDs.compactMap { $0.uuidString })
        self.serviceData = serviceData
        self.manufacturerData = manufacturerData
    }

    public init(advertisementData: [String: Any], name: String?, rssi: Int?) {
        let serviceUUIDs = Set(advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? Advertisement.ServiceData
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let name = name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"

        var discoveryTimestamp: Date = Date()
        if let timestamp = advertisementData["kCBAdvDataTimestamp"] as? TimeInterval {
            discoveryTimestamp = Date(timeIntervalSinceReferenceDate: timestamp)
        }
        self.init(
            name: name,
            advertisementData: advertisementData,
            serviceUUIDs: serviceUUIDs,
            serviceData: serviceData,
            manufacturerData: manufacturerData,
            rssi: rssi,
            timestamp: discoveryTimestamp
        )
    }

}

// MARK: - Hashable
extension Advertisement: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(serviceUUIDs)
        hasher.combine(serviceData)
    }

    public static func == (lhs: Advertisement, rhs: Advertisement) -> Bool {
        return lhs.serviceUUIDs == rhs.serviceUUIDs && lhs.serviceData == rhs.serviceData
    }
}

// MARK: - CustomStringConvertible
extension Advertisement: CustomStringConvertible {
    public var description: String {
        let descriptionComponents = [
            "name=\(name)",
            "rssi=\(String(describing: rssi)) dB",
            "timestamp=\(timestamp)",
            "serviceUUIDs:\(String(describing: serviceUUIDs))"
        ]
        return descriptionComponents.joined(separator: " ")
    }
}
