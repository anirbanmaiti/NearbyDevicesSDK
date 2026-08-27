//
//  BlePeripheralContext.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Combine
import Foundation

/// Helper class containing the objects necessary to track a Peripheral's commands.
actor BlePeripheralContext {

    var characteristicValueUpdateStream: AsyncStream<(CoreCharacteristic, Data?)> {
        characteristicValueUpdateSubject.compactMap { $0 }.stream
    }

    func flush(error: Error) async {
        for flushableExecutor in flushableExecutors {
            await flushableExecutor.flush(error: error)
        }
    }

    // MARK: Initialization
    init(delegateWrapper: BlePeripheralDelegateWrapper, logger: NDLoggerProtocol?) {
        self.delegateWrapper = delegateWrapper
        self.logger = logger
        let connectToPeripheralExecutor = AsyncSerialExecutor<Void>()
        let readRSSIExecutor = AsyncSerialExecutor<Int>()
        let discoverServiceExecutor = AsyncSerialExecutor<[CoreService]>()
        let discoverCharacteristicsExecutor = AsyncExecutorMap<CoreUUID, [CoreCharacteristic]>()
        let readCharacteristicValueExecutor = AsyncExecutorMap<CoreUUID, Data?>()
        let writeCharacteristicValueExecutor = AsyncExecutorMap<CoreUUID, Void>()
        let setNotifyValueExecutor = AsyncExecutorMap<CoreUUID, Void>()
        self.connectToPeripheralExecutor = connectToPeripheralExecutor
        self.readRSSIExecutor = readRSSIExecutor
        self.discoverServiceExecutor = discoverServiceExecutor
        self.discoverCharacteristicsExecutor = discoverCharacteristicsExecutor
        self.readCharacteristicValueExecutor = readCharacteristicValueExecutor
        self.writeCharacteristicValueExecutor = writeCharacteristicValueExecutor
        self.setNotifyValueExecutor = setNotifyValueExecutor
        self.flushableExecutors = [
            connectToPeripheralExecutor,
            readRSSIExecutor,
            discoverServiceExecutor,
            discoverCharacteristicsExecutor,
            readCharacteristicValueExecutor,
            writeCharacteristicValueExecutor,
            setNotifyValueExecutor
        ]
        Task { [weak self] in
            await self?.setupSubscriptions()
        }
    }

    deinit {
        cancellableTasks.forEach { $0.cancel() }
    }

    private let characteristicValueUpdateSubject = PassthroughSubject<(CoreCharacteristic, Data?)?, Never>()
    func notifyCharacteristicValueUpdated(_ characteristic: CoreCharacteristic, value: Data?) {
        characteristicValueUpdateSubject.send((characteristic, value))
    }

    let connectToPeripheralExecutor: AsyncSerialExecutor<Void>

    let readRSSIExecutor: AsyncSerialExecutor<Int>

    func didReadRSSI(_ peripheral: CorePeripheralRepresentable, rssi: Int, error: Error?) async {
        do {
            let result = ResultUtils.result(for: rssi, error: error, resultingError: BluetoothError.peripheralRSSIReadFailed(peripheral.identifier, error))
            try await readRSSIExecutor.setWorkCompletedWithResult(result)
        } catch {
            logger?.logDebug("Received ReadRSSI response without a continuation")
        }
    }

    let discoverServiceExecutor: AsyncSerialExecutor<[CoreService]>

    func didDiscoverServices(_ peripheral: CorePeripheralRepresentable, error: Error?) async {
        do {
            let result = ResultUtils.result(for: (peripheral.services?.compactMap { $0 as CoreService }) ?? [], error: error, resultingError: BluetoothError.servicesDiscoveryFailed(peripheral.identifier, error))
            try await discoverServiceExecutor.setWorkCompletedWithResult(result)
        } catch {
            logger?.logDebug("Received DiscoverServices response without a continuation. \(peripheral)")
        }
    }

    let discoverCharacteristicsExecutor: AsyncExecutorMap<CoreUUID, [CoreCharacteristic]>

    private func didDiscoverCharacteristicsFor(_ peripheral: CorePeripheralRepresentable, service: CoreService, error: Error?) async {
        do {
            let result = ResultUtils.result(for: service.cbcharacteristics ?? [], error: error, resultingError: BluetoothError.characteristicsDiscoveryFailed(service.uuid, error))
            try await discoverCharacteristicsExecutor.setWorkCompletedForKey(
                service.uuid, result: result
            )
        } catch {
            logger?.logDebug("Received DiscoverCharacteristics result without a continuation. \(peripheral)")
        }
    }

    let readCharacteristicValueExecutor: AsyncExecutorMap<CoreUUID, Data?>

    func didUpdateValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, value: Data?, error: Error?) async {
        if characteristic.isNotifying {
            // characteristic.value is Data() and it will get trampled if allowed to run async.
            notifyCharacteristicValueUpdated(characteristic, value: value)
        }
        do {
            let result = ResultUtils.result(for: value, error: error, resultingError: BluetoothError.characteristicReadFailed(characteristic.uuid, error))
            try await readCharacteristicValueExecutor.setWorkCompletedForKey(
                characteristic.uuid, result: result
            )
        } catch {
            guard !characteristic.isNotifying else { return }
            logger?.logDebug("Received UpdateValue result for characteristic without a continuation")
        }
    }

    let writeCharacteristicValueExecutor: AsyncExecutorMap<CoreUUID, Void>

    func didWriteValueFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?) async {
        do {
            let result = ResultUtils.result(for: (), error: error, resultingError: BluetoothError.characteristicWriteFailed(characteristic.uuid, error))
            try await writeCharacteristicValueExecutor.setWorkCompletedForKey(
                characteristic.uuid, result: result
            )
        } catch {
            logger?.logDebug("Received WriteValue result for characteristic without a continuation")
        }
    }

    let setNotifyValueExecutor: AsyncExecutorMap<CoreUUID, Void>

    func didUpdateNotificationStateFor(_ peripheral: CorePeripheralRepresentable, characteristic: CoreCharacteristic, error: Error?) async {
        do {
            let result = ResultUtils.result(for: (), error: error, resultingError: BluetoothError.characteristicSetNotifyValueFailed(characteristic.uuid, error))
            try await setNotifyValueExecutor.setWorkCompletedForKey(
                characteristic.uuid, result: result
            )
        } catch {
            logger?.logDebug("Received UpdateNotificationState result without a continuation")
        }
    }

    private func setupSubscriptions() {
        delegateWrapper.eventStream.sink { [weak self] event in
            guard let self else { return }
            switch event {
                case let .didReadRSSI(peripheral, rssi, error):
                    await self.didReadRSSI(peripheral, rssi: rssi, error: error)
                case let .didDiscoverServices(peripheral, error):
                    await self.didDiscoverServices(peripheral, error: error)
                case let .didDiscoverCharacteristicsForService(peripheral, service, error):
                    await self.didDiscoverCharacteristicsFor(peripheral, service: service, error: error)
                case let .didUpdateValueForCharacteristic(peripheral, characteristics, value, error):
                    await self.didUpdateValueFor(peripheral, characteristic: characteristics, value: value, error: error)
                case let .didWriteValueForCharacteristic(peripheral, characteristics, error):
                    await self.didWriteValueFor(peripheral, characteristic: characteristics, error: error)
                case let .didUpdateNotificationStateForCharacteristic(peripheral, characteristics, error):
                    await self.didUpdateNotificationStateFor(peripheral, characteristic: characteristics, error: error)
            }
        }
        .store(in: &cancellableTasks)
    }

    // MARK: Private
    private let delegateWrapper: BlePeripheralDelegateWrapper
    private let logger: NDLoggerProtocol?
    private let flushableExecutors: [FlushableExecutor]
    private var cancellableTasks = Set<Task<Void, any Error>>()
}
