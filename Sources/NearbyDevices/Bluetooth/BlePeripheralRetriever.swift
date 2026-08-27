//
//  BlePeripheralRetriever.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

/// Retrieves `BlePeripheral` by peripheral identifier.
/// This component retrives the `CorePeripheralRepresentable` from `BluetoothManager` and make and store `BlePeripheral` wrapper.
/// Upon Bluetooth poweredOff, cache is reset.
protocol BlePeripheralRetrieving: Actor {

    /// Returns list of `BlePeripheral`s by their identifiers which are known to `BluetoothManager`.
    ///
    /// - parameter identifiers: List of peripheral identifiers.
    /// - returns: Dictionary of retrieved `BlePeripheral`s.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    func retrieveBlePeripherals(withIdentifiers identifiers: [UUID]) async throws -> [UUID: BlePeripheral]

    /// Returns `BlePeripheral`s by identifier which are known to `BluetoothManager`.
    ///
    /// - parameter identifier: peripheral identifier.
    /// - returns: Retrieved `BlePeripheral`.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    /// `BluetoothError.peripheralNotFound` - if peripheral cannot be retrived from CBCentralManager.
    func retrieveBlePeripheral(withIdentifier identifier: UUID) async throws -> BlePeripheral

    /// Returns connected `BlePeripheral`s by identifier which are known to `BluetoothManager`.
    ///
    /// - returns: List of retrieved connected `BlePeripheral`.
    /// - Throws: `BluetoothError.bluetoothManagerUnavailable`
    /// `BluetoothError.peripheralNotFound` - if peripheral cannot be retrived from CBCentralManager.
    func retrieveConnectedBlePeripherals() async throws -> [BlePeripheral]
}

extension BlePeripheralRetriever {
    func retrieveBlePeripheral(withIdentifier identifier: UUID) async throws -> BlePeripheral {
        let peripheralMap = try await retrieveBlePeripherals(withIdentifiers: [identifier])
        guard let blePeripheral = peripheralMap[identifier] else {
            throw BluetoothError.peripheralNotFound
        }
        return blePeripheral
    }
}

final actor BlePeripheralRetriever: BlePeripheralRetrieving {

    func retrieveBlePeripherals(withIdentifiers identifiers: [UUID]) async throws -> [UUID: BlePeripheral] {
        let peripherals = try await bluetoothManager.retrievePeripherals(withIdentifiers: identifiers)
        var result = [UUID: BlePeripheral]()
        for peripheral in peripherals {
            result[peripheral.identifier] = provide(for: peripheral)
        }
        return result
    }

    func retrieveConnectedBlePeripherals() async throws -> [BlePeripheral] {
        let peripherals = try await bluetoothManager.retrieveConnectedPeripherals()
        var result = [BlePeripheral]()
        for peripheral in peripherals {
            result.append(provide(for: peripheral))
        }
        return result
    }

    // MARK: Initialization
    init(bluetoothManager: BluetoothManaging, logger: NDLoggerProtocol?) {
        self.bluetoothManager = bluetoothManager
        self.logger = logger
        Task {
            await setupSubscriptions()
        }
    }

    // MARK: Private
    private func setupSubscriptions() async {
        await bluetoothManager.bluetoothState.sink { [weak self] state in
            if state == .poweredOff {
                await self?.removeAll()
            }
        }
        .store(in: &subscriptions)
    }

    private func provide(for cbPeripheral: CorePeripheralRepresentable) -> BlePeripheral {
        if let peripheral = find(cbPeripheral) {
            return peripheral
        }
        return makeAndAddToBox(cbPeripheral)
    }

    private func makeAndAddToBox(_ cbPeripheral: CorePeripheralRepresentable) -> BlePeripheral {
        let bluetoothPeripheral = BlePeripheral(manager: bluetoothManager, peripheral: cbPeripheral, logger: logger)
        peripheralsBox.updateValue(bluetoothPeripheral, forKey: cbPeripheral.identifier)
        return bluetoothPeripheral
    }

    private func find(_ cbPeripheral: CorePeripheralRepresentable) -> BlePeripheral? {
        guard let bluetoothPeripheral = peripheralsBox[cbPeripheral.identifier], bluetoothPeripheral.peripheral === cbPeripheral else {
            return nil
        }
        return bluetoothPeripheral
    }

    private func removeAll() {
        peripheralsBox.removeAll()
    }

    private let bluetoothManager: BluetoothManaging
    private let logger: NDLoggerProtocol?
    private var peripheralsBox = [UUID: BlePeripheral]()
    private var subscriptions = Set<AnyCancellable>()
}

extension NearbyDevicesGate {
    func makeBlePeripheralRetriever() -> BlePeripheralRetrieving {
        BlePeripheralRetriever(bluetoothManager: centralManager, logger: logger)
    }
}
