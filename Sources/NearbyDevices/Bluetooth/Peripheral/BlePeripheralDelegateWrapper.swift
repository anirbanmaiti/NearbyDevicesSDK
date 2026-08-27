//
//  BlePeripheralDelegateWrapper.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// CorePeripheralDelegate delegate handler class
final class BlePeripheralDelegateWrapper: NSObject, @unchecked Sendable {

    /// Stream of BluetoothManagerEvents
    lazy var eventStream: AsyncStream<BlePeripheralEvent> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init(logger: NDLoggerProtocol?) {
        self.logger = logger
    }

    deinit {
        continuation?.finish()
        continuation = nil
    }
    // MARK: Private
    private var continuation: AsyncStream<BlePeripheralEvent>.Continuation?
    private var logger: NDLoggerProtocol?
}

// MARK: CorePeripheralDelegate handlers
extension BlePeripheralDelegateWrapper: CorePeripheralDelegate {
    func didReadRSSI(_ peripheral: CorePeripheralRepresentable, RSSI: NSNumber, error: Error?) {
        continuation?.yield(.didReadRSSI(peripheral, RSSI.intValue, error))
    }

    func didDiscoverServices(_ peripheral: CorePeripheralRepresentable, error: Error?) {
        continuation?.yield(.didDiscoverServices(peripheral, error))
    }

    func didDiscoverCharacteristicsFor(_ peripheral: CorePeripheralRepresentable, service: CoreService, error: Error?) {
        continuation?.yield(.didDiscoverCharacteristicsForService(peripheral, service, error))
    }

    func didUpdateValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?) {
        continuation?.yield(.didUpdateValueForCharacteristic(peripheral, characteristic, characteristic.value, error))
    }

    func didWriteValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?) {
        continuation?.yield(.didWriteValueForCharacteristic(peripheral, characteristic, error))
    }

    func didUpdateNotificationStateFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?) {
        continuation?.yield(.didUpdateNotificationStateForCharacteristic(peripheral, characteristic, error))
    }
}
