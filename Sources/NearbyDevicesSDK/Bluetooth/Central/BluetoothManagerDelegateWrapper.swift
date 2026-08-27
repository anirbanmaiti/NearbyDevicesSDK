//
//  BluetoothManagerDelegateWrapper.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

@preconcurrency import Combine
import Foundation

/// A helper class that handles `CBCentralManager` delegates and sends them to `BluetoothManagerContext`
final class BluetoothManagerDelegateWrapper: @unchecked Sendable {

    /// Stream of BluetoothManagerEvents
    lazy var eventStream: AsyncStream<BluetoothManagerEvent> = {
        AsyncStream {[weak self] continuation in
            self?.continuation = continuation
        }
    }()

    /// Stream of PeripheralConnectionEvent
    lazy var connectionEventStream: AsyncStream<PeripheralConnectionEvent> = {
        AsyncStream { [weak self] continuation in
            self?.connectionEventContinuation = continuation
        }
    }()

    init(logger: NDLoggerProtocol?) {
        self.logger = logger
    }

    deinit {
        continuation?.finish()
        continuation = nil
        connectionEventContinuation?.finish()
        connectionEventContinuation = nil
    }

    // MARK: Private
    private var continuation: AsyncStream<BluetoothManagerEvent>.Continuation?
    private var connectionEventContinuation: AsyncStream<PeripheralConnectionEvent>.Continuation?
    private let logger: NDLoggerProtocol?
}

extension BluetoothManagerDelegateWrapper: CoreCentralManagerDelegate {

    func didUpdateState(central: CoreCentralManaging) {
        continuation?.yield(.didUpdateState(state: BluetoothState(central.state)))
    }

    func didDiscover(peripheral: CorePeripheralRepresentable, advertisementData: [String: Any], rssi RSSI: Int?) {
        let discoveryEvent = PeripheralDiscoveryEvent(
            identifier: peripheral.identifier,
            name: peripheral.name,
            advertisementData: advertisementData,
            rssi: RSSI
        )
        continuation?.yield(.didDiscover(event: discoveryEvent))
    }

    func didConnect(peripheral: CorePeripheralRepresentable) {
        connectionEventContinuation?.yield(.didConnectPeripheral(peripheral: peripheral))
    }

    func didDisconnectPeripheral(peripheral: CorePeripheralRepresentable, error: Error?) {
        connectionEventContinuation?.yield(.didDisconnectPeripheral(peripheral: peripheral, error: error))
    }

    func didFailToConnect(peripheral: CorePeripheralRepresentable, error: Error?) {
        connectionEventContinuation?.yield(.didFailToConnect(peripheral: peripheral, error: error))
    }
}
