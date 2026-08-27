//
//  ScanRequest.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

struct ScanRequest: Hashable {

    /// Scan request unique identifier.
    let identifier: UUID

    /// scan reason.
    let reason: ScanRequestReason

    /// scan duration
    let duration: TimeInterval?

    /// Initialization
    ///
    /// - Parameters:
    ///   - uuid: unique identifier for the request.
    ///   - reason: scan reason object.
    ///   - duration: scan duration.
    init(identifier: UUID = UUID(), reason: ScanRequestReason, duration: TimeInterval? = nil) {
        self.identifier = identifier
        self.reason = reason
        self.duration = duration
    }
}
