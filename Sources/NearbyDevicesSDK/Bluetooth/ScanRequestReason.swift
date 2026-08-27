//
//  ScanRequestReason.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

/// Type of scan request
public enum ScanRequestReason: String, Sendable {
    /// Scan without duplicate filtering. Can be used for RSSI sampling.
    case focus

    /// Scan with duplicate filtering.
    case background
}

/// Mapping to corresponding serviceUUIDs and duplicate filtering
extension ScanRequestReason {
    
    /// Corresponding ServiceUUIDs for the request
    var defaultServiceUUIDs: [CoreUUID] {
        switch self {
        case .focus, .background: return []
        }
    }
    
    /// Denotes whether the request allows duplicate discovery.
    var allowDuplicates: Bool {
        switch self {
        case .focus:
            return true
        case .background:
            return false
        }
    }
}

struct ScanServiceUUIDProvider {
    func serviceUUIDs(for scanReason: ScanRequestReason) -> Set<CoreUUID> {
        switch scanReason {
        case .focus, .background:
            return Set(scanReason.defaultServiceUUIDs)
        }
    }
}
