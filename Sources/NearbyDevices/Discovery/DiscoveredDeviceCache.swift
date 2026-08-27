//
//  DiscoveredDeviceCache.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Combine
import Foundation

protocol DiscoveredDeviceCaching: Sendable {

    /// Discovered device stream.
    var deviceDiscoveryStream: AsyncStream<DiscoveredDevice> { get async }

    /// Updates the devices cache when a new device is seen. This will trigger the publisher to emit.
    /// - Parameter device: The `DiscoveredDevice` instance that was discovered.
    func onDeviceSeen(_ device: DiscoveredDevice) async

    /// Retrieves a `DiscoveredDevice` associated with a given peripheral identifier.
    /// - Parameter peripheralIdentifier: The UUID of the peripheral device.
    /// - Returns: An optional `DiscoveredDevice` if found, otherwise `nil`.
    func getDevice(peripheralID: UUID) async -> DiscoveredDevice?

    /// Returns `CurrentValueStream` that publishes a Set of nearby devices as a Set<DiscoveredDevice>. This Publisher will publish on each change such as a new device being discovered or as devices become stale
    /// - Parameters:
    ///   - maxAge: The "max age" of a discovered device. For example a value of 30 here will remove devices that are 30 seconds old.
    func nearbyDevicesStream(maxAge: TimeInterval) async -> CurrentValueStream<Set<DiscoveredDevice>>

    /// Removes all discovered devices.
    func reset() async
}

actor DiscoveredDeviceCache: DiscoveredDeviceCaching {

    var deviceDiscoveryStream: AsyncStream<DiscoveredDevice> {
        discoveredDeviceSubject.eraseToAnyPublisher().stream
    }

    func nearbyDevicesStream(maxAge: TimeInterval) async -> CurrentValueStream<Set<DiscoveredDevice>> {
        resetWatchdogTimerIfNeeded(maxAge: maxAge)

        let filter: ((Set<DiscoveredDevice>) -> Set<DiscoveredDevice>) = { devices in
            devices.filter { $0.isConnected || Date().timeIntervalSince($0.lastUpdated) <= maxAge }
        }

        let currentSet = filter(Set(devices.values))
        let nearbyPublisher = publisher
            .map { filter($0) }
            .eraseToAnyPublisher()
        return CurrentValueStream(publisher: nearbyPublisher, initialValue: currentSet)
    }

    func onDeviceSeen(_ device: DiscoveredDevice) async {
        guard await bluetoothStateObserver.bluetoothState.value == .poweredOn else { return }

        // Encountered discovery event after connected event. Likely event queue delivered discovery event with queue delay.
        // DiscoveredDeviceCache receives discovery events with 1 sec delay (due to batched private id decoding).
        // And in race condition, the connection status changes from "disconnected"->"connected" within that 1 sec.
        // We see this race very rarely so this logic should take care of that corner case.
        do {
            if let existingDevice = devices[device.peripheralIdentifier],
               existingDevice.isConnected, !device.isConnected,
               let peripheral = try await bluetoothConnectionManager.retrievePeripherals(withIdentifiers: [device.peripheralIdentifier]).first,
               peripheral.state == .connected {
                return
            }
        } catch {
            logger?.logDebug("Failed to retrieve peripheral. \(device)")
            return
        }

        // store device
        addOrUpdateDevice(device)
        // publish
        publishDeviceInstantaneous(device)
        publishDevices()
        // restart timer
        timer.kick()
    }

    func getDevice(peripheralID: UUID) -> DiscoveredDevice? {
        devices[peripheralID]
    }

    func reset() {
        cleanup()
    }

    init(
        maxAge: TimeInterval = 300,
        bluetoothStateObserver: BluetoothStateObservable,
        bluetoothConnectionManager: BluetoothConnectionManaging,
        logger: NDLoggerProtocol? = nil
    ) {
        self.highestMaxAge = maxAge
        self.bluetoothStateObserver = bluetoothStateObserver
        self.bluetoothConnectionManager = bluetoothConnectionManager
        self.logger = logger
        timer = AsyncWatchdogTimer(interval: highestMaxAge)
        timer.delegate = self
        Task {
            await setupSubscription()
        }
    }

    deinit {
//        discoveredDeviceSubject.send(completion: .finished)
        subscribedTasks.forEach { $0.cancel() }
        subscribedTasks.removeAll()
    }

    // MARK: Private
    private func setupSubscription() async {
        await self.bluetoothStateObserver.bluetoothState.sink { [weak self] bluetoothState in
            guard let self else { return }
            guard bluetoothState != .poweredOn else { return }
            await cleanup()
        }
        .store(in: &subscriptions)

        await bluetoothConnectionManager.connectionEventsStream.sink { [weak self] peripheralConnectionEvent in
            guard let self else { return }

            switch peripheralConnectionEvent {
                case .didConnectPeripheral(let peripheral):
                    await updateDeviceConnectedState(peripheral.identifier, isConnected: true)
                case .didDisconnectPeripheral(let peripheral, _):
                    await updateDeviceConnectedState(peripheral.identifier, isConnected: false)
                case .didFailToConnect(let peripheral, _):
                    await updateDeviceConnectedState(peripheral.identifier, isConnected: false)
            }
        }
        .store(in: &subscribedTasks)
    }

    private func addOrUpdateDevice(_ device: DiscoveredDevice) {
        devices[device.peripheralIdentifier] = device
    }

    private func publishDevices() {
        publisher.send(Set(devices.values))
    }

    private func resetWatchdogTimerIfNeeded(maxAge: TimeInterval) {
        if maxAge > highestMaxAge {
            // If the requested max age is higher then update the timer
            timer.interval = maxAge
            // restart the timer
            timer.kick()
        }
    }

    private func cleanup() {
        devices.removeAll()
        publishDevices()
    }

    private func updateDeviceConnectedState(_ peripheralID: UUID, isConnected: Bool) {
        guard var device = getDevice(peripheralID: peripheralID), device.isConnected != isConnected else { return }
        device.updateConnected(isConnected)
        devices.updateValue(device, forKey: peripheralID)
        publishDeviceInstantaneous(device)
        publishDevices()
    }

    private func publishDeviceInstantaneous(_ device: DiscoveredDevice) {
        discoveredDeviceSubject.send(device)
    }

    private let bluetoothStateObserver: BluetoothStateObservable
    private let bluetoothConnectionManager: BluetoothConnectionManaging
    private let logger: NDLoggerProtocol?
    private var timer: AsyncWatchdogTimer
    let highestMaxAge: TimeInterval
    private var publisher = PassthroughSubject<Set<DiscoveredDevice>, Never>()
    private var devices = [UUID: DiscoveredDevice]()
    private let discoveredDeviceSubject = PassthroughSubject<DiscoveredDevice, Never>()
    private var subscriptions = [AnyCancellable]()
    private var subscribedTasks = Set<Task<Void, Error>>()
}

// MARK: AsyncWatchdogTimerDelegate
extension DiscoveredDeviceCache: AsyncWatchdogTimerDelegate {
    func asyncWatchdogTimerDidTimeout(_ timer: AsyncWatchdogTimer) {
        // reset timer to original injected value
        timer.interval = highestMaxAge
        // timer completed so all data aged out
        for (peripheralID, device) in devices {
            if Date().timeIntervalSince(device.lastUpdated) > highestMaxAge, !device.isConnected {
                devices[peripheralID] = nil
            }
        }
        if !devices.isEmpty {
            timer.kick()
        }
        // publish
        publishDevices()
    }
}

extension NearbyDiscoveryComponent {
    func makeDiscoveredDeviceCache() -> DiscoveredDeviceCaching {
        DiscoveredDeviceCache(
            maxAge: 600,
            bluetoothStateObserver: centralManager,
            bluetoothConnectionManager: centralManager,
            logger: logger
        )
    }
}
