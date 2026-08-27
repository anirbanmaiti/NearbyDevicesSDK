//
//  PeripheralScanRequest.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Scan request used by Central Manager for scanning
struct PeripheralScanRequest: Equatable, Sendable {
    static func == (lhs: PeripheralScanRequest, rhs: PeripheralScanRequest) -> Bool {
        return lhs.scanReasons.elementsEqual(rhs.scanReasons)
    }

    /// Set of resolved reasons used for the scan
    let scanReasons: Set<ScanRequestReason>

    /// Requested Service UUIDs for the scan. Calculated from scan reasons.
    var serviceUUIDs: Set<CoreUUID> {
        scanReasons.reduce(into: Set<CoreUUID>()) {
            $0 = $0.union(serviceUUIDProvider.serviceUUIDs(for: $1))
        }
    }

    /// Flag denotes if duplicate filitering needed. Ref: `CBCentralManagerScanOptionAllowDuplicatesKey` Calculated from scan reasons.
    var allowDuplicates: Bool {
        scanReasons.contains { $0.allowDuplicates }
    }

    init(scanReasons: Set<ScanRequestReason>,
         featureFlagProvider: NDFeatureFlagProviding) {
        self.scanReasons = scanReasons
        self.serviceUUIDProvider = ScanServiceUUIDProvider()
    }
    private let serviceUUIDProvider: ScanServiceUUIDProvider
}

extension PeripheralScanRequest: CustomStringConvertible {
    var description: String {
        let descriptionComponents = [
            "scanReasons=\(scanReasons)",
            "ServiceUUID=\(serviceUUIDs)",
            "allowDuplicates: \(allowDuplicates)"
        ]
        return descriptionComponents.joined(separator: " ")
    }
}
