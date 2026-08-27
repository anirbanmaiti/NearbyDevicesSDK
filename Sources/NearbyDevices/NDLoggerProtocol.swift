//
//  NDLoggerProtocol.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Foundation

public enum LogLevel {
    case VERBOSE, DEBUG, INFO, WARN, ERROR, API
}

public protocol NDLoggerProtocol: Sendable {
    func log(_ tag: String, _ logLevel: LogLevel, _ message: String)
}

// MARK: - Internal
enum LoggerTag: String {
    /// Default tag
    case `default` = "ND |"

    /// Bluetooth related logging tag.
    case ble = "ND | BLE |"

    /// log API related tag
    case apiCall = "ND | API |"
}

extension NDLoggerProtocol {
    func logInfo(_ message: String, tag: LoggerTag = .default) {
        log(tag.rawValue, .INFO, message)
    }

    func logError(_ message: String, tag: LoggerTag = .default) {
        log(tag.rawValue, .ERROR, message)
    }

    func logDebug(_ message: String, tag: LoggerTag = .default) {
        log(tag.rawValue, .DEBUG, message)
    }
}
