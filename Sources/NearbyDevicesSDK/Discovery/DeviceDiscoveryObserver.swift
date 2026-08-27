//
//  DeviceDiscoveryObserver.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Combine
import Foundation

/// Observes batched discovery events and resolves service data if possible.
/// Converts `PeripheralDiscoveryEvent` to `DiscoveredDevice`.
protocol DeviceDiscoveryObservable: Sendable {

    /// Discovered device stream.
    var deviceDiscoveryStream: AsyncStream<DiscoveredDevice> { get async }

    /// Initialization
    ///
    /// - Parameters:
    ///  - peripheralDiscoveryObserver: Central manager discovery observer object.
    ///  - privateIDResolver: Private ID resolver object.
    ///  - logger: Logger object.
    init(
        peripheralDiscoveryObserver: PeripheralDiscoveryObservable,
        logger: NDLoggerProtocol?
    )
}

actor DeviceDiscoveryObserver: DeviceDiscoveryObservable {

    // MARK: API
    var deviceDiscoveryStream: AsyncStream<DiscoveredDevice> {
        get async {
            await setupSubscriptions()
            return processedEventsSubject.eraseToAnyPublisher().stream
        }
    }
    // MARK: Initialize
    init(
        peripheralDiscoveryObserver: PeripheralDiscoveryObservable,
        logger: NDLoggerProtocol?
    ) {
        self.logger = logger
        self.peripheralDiscoveryObserver = peripheralDiscoveryObserver
        Task {
            await setupSubscriptions()
        }
    }

    deinit {
//        processedEventsSubject.send(completion: .finished)
        subscribedTasks.forEach { $0.cancel() }
        subscribedTasks.removeAll()
    }

    // MARK: Private
    private func setupSubscriptions() async {
        guard !isSubscribed else { return }
        isSubscribed = true
        await peripheralDiscoveryObserver.peripheralDiscoveryStream.sink {[weak self] events in
            await self?.didPeripheralDiscovered(events: events)
        }
        .store(in: &subscribedTasks)
    }

    private func didPeripheralDiscovered(events: [PeripheralDiscoveryEvent]) async {
        for event in events {
            let device = DiscoveredDevice(peripheralIdentifier: event.identifier, advertisement: event.advertisement)
                processedEventsSubject.send(device)
        }
    }

    private var peripheralDiscoveryObserver: PeripheralDiscoveryObservable
    private let logger: NDLoggerProtocol?
    private let processedEventsSubject = PassthroughSubject<DiscoveredDevice, Never>()
    private var isSubscribed = false
    private var subscribedTasks = Set<Task<Void, Error>>()
}

extension NearbyDiscoveryComponent {
    func makeDeviceDiscoveryObserver() -> DeviceDiscoveryObservable {
        let peripheralDiscoveryObserver = makePeripheralDiscoveryObserver()
        return DeviceDiscoveryObserver(
            peripheralDiscoveryObserver: peripheralDiscoveryObserver,
            logger: logger
        )
    }
}
