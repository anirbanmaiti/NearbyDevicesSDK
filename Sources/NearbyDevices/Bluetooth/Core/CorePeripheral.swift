//
//  CorePeripheral.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import CoreBluetooth

// Wrapper for CBPeripheral. CorePeripheralRepresentable encapsulates CoreBluetooth dependencies.
final class CorePeripheral: NSObject, CorePeripheralRepresentable {

    let objectId: UUID

    let identifier: UUID

    nonisolated(unsafe) let cbPeripheral: CBPeripheral

    var name: String? {
        cbPeripheral.name
    }

    nonisolated(unsafe) weak var delegate: CorePeripheralDelegate? {
        didSet {
            guard delegate != nil else {
                cbPeripheral.delegate = nil
                wrapper = nil
                return
            }
            wrapper = CBPeripheralDelegateWrapper(self, logger: logger)
            cbPeripheral.delegate = wrapper
        }
    }

    var state: CorePeripheralState {
        cbPeripheral.state
    }

    var services: [CoreService]? {
        cbPeripheral.services
    }

    var canSendWriteWithoutResponse: Bool {
        cbPeripheral.canSendWriteWithoutResponse
    }

    func readRSSI() {
        cbPeripheral.readRSSI()
    }

    func discoverServices(_ serviceUUIDs: [CoreUUID]?) {
        logger?.logDebug("> discoverServices: \(String(describing: serviceUUIDs))", tag: .ble)
        cbPeripheral.discoverServices(serviceUUIDs)
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CoreUUID]?, for service: CoreService) {
        guard let cbService = service as? CBService else { return }
        logger?.logDebug("> discoverCharacteristics: \(String(describing: characteristicUUIDs))", tag: .ble)
        cbPeripheral.discoverCharacteristics(characteristicUUIDs, for: cbService)
    }

    func readValue(for characteristic: CoreCharacteristic) {
        guard let cbCharacteristic = characteristic as? CBCharacteristic else { return }
        logger?.logDebug("> readCharacteristicValue: \(characteristic)", tag: .ble)
        cbPeripheral.readValue(for: cbCharacteristic)
    }

    func maximumWriteValueLength(for type: CoreCharacteristicWriteType) -> Int {
        return cbPeripheral.maximumWriteValueLength(for: type)
    }

    func writeValue(_ data: Data, for characteristic: CoreCharacteristic, type: CoreCharacteristicWriteType) {
        guard let cbCharacteristic = characteristic as? CBCharacteristic else { return }
        #if DEBUG
        logger?.logDebug("> writeValue: <\(data as NSData)> to \(characteristic)", tag: .ble)
        #endif
        cbPeripheral.writeValue(data, for: cbCharacteristic, type: type)
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CoreCharacteristic) {
        guard let cbCharacteristic = characteristic as? CBCharacteristic else { return }
        logger?.logDebug("> setNotifyValue: \(enabled) for \(characteristic)", tag: .ble)
        cbPeripheral.setNotifyValue(enabled, for: cbCharacteristic)
    }

    // MARK: Initialization
    init(peripheral: CBPeripheral, objectId: UUID = UUID(), logger: NDLoggerProtocol?) {
        self.identifier = peripheral.identifier
        self.cbPeripheral = peripheral
        self.objectId = objectId
        self.logger = logger
        super.init()
    }

    // MARK: Private
    private let logger: NDLoggerProtocol?
    nonisolated(unsafe) private var wrapper: CBPeripheralDelegateWrapper?

    private class CBPeripheralDelegateWrapper: NSObject, CBPeripheralDelegate {
        fileprivate weak var peripheral: CorePeripheralRepresentable? // weak to avoid cyclic reference
        private let logger: NDLoggerProtocol?

        init(_ peripheral: CorePeripheralRepresentable, logger: NDLoggerProtocol?) {
            self.peripheral = peripheral
            self.logger = logger
        }

        func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didReadRSSI(peripheral, RSSI: RSSI, error: error)
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            logger?.logDebug("< didDiscoverServices: \(peripheral), \(String(describing: error))", tag: .ble)
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didDiscoverServices(peripheral, error: error)
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            logger?.logDebug("< didDiscoverCharacteristicsFor \(service): \(String(describing: error))", tag: .ble)
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didDiscoverCharacteristicsFor(peripheral, service: service, error: error)
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didUpdateValueFor(peripheral, characteristic: characteristic, error: error)
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didWriteValueFor(peripheral, characteristic: characteristic, error: error)
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            logger?.logDebug("< didUpdateNotificationStateForCharacteristic: \(characteristic): \(String(describing: error))", tag: .ble)
            guard let peripheral = self.peripheral else { return }
            self.peripheral?.delegate?.didUpdateNotificationStateFor(peripheral, characteristic: characteristic, error: error)
        }
    }
}

extension CorePeripheral {
    override var description: String {
        return "\(cbPeripheral)"
    }
}
