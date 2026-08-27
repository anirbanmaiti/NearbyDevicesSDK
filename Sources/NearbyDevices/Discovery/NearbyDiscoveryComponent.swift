//
//  NearbyDiscoveryComponent.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import Foundation

final class NearbyDiscoveryComponent: NearbyDevicesDiscoveryAPI {

    func nearbyDevicesStream(maxAge: TimeInterval) async -> CurrentValueStream<Set<DiscoveredDevice>> {
        await discoveredDeviceCache.nearbyDevicesStream(maxAge: maxAge)
    }

    // MARK: - API
    func search(reason: ScanRequestReason, duration: TimeInterval? = nil) async throws {
        self.logger?.logDebug("search reason:\(reason) duration: \(duration ?? 0)", tag: .apiCall)
        let handle = await scanController.requestScan(reason: reason, duration: duration)
        scanHandles[reason] = handle
    }

    func stopSearch(reason: ScanRequestReason) async {
        self.logger?.logDebug("stopSearch reason:\(reason)", tag: .apiCall)
        guard let handle = scanHandles[reason] else {
            return
        }
        scanHandles[reason] = nil
        await handle.cancel()
    }

    // Cache for all discovered devices
    internal lazy var discoveredDeviceCache = makeDiscoveredDeviceCache()

    // MARK: - Initialization
    init(centralManager: BluetoothManaging,
         scanController: ScanControlling,
         featureFlagProvider: NDFeatureFlagProviding,
         logger: NDLoggerProtocol?,
         applicationGroup: String) {

        self.centralManager = centralManager
        self.scanController = scanController
        self.featureFlagProvider = featureFlagProvider
        self.logger = logger
        self.applicationGroup = applicationGroup
        setup()
    }

    private func setup() {
        let discoveredDeviceCache = discoveredDeviceCache
        let deviceDiscoveryObserver = deviceDiscoveryObserver
        Task {
            await deviceDiscoveryObserver.deviceDiscoveryStream.sink { [discoveredDeviceCache] device in
                await discoveredDeviceCache.onDeviceSeen(device)
            }
        }
    }

    // MARK: - Private
    internal let centralManager: BluetoothManaging
    internal let logger: NDLoggerProtocol?
    internal let applicationGroup: String
    internal let featureFlagProvider: NDFeatureFlagProviding

    lazy var deviceDiscoveryObserver: DeviceDiscoveryObservable = makeDeviceDiscoveryObserver()
    private let scanController: ScanControlling
    @ThreadSafe private var scanHandles: [ScanRequestReason: RequestHandling] = [:]
}

extension NearbyDevicesGate {
    func makeNDDiscoveryComponent() -> NearbyDiscoveryComponent {
        NearbyDiscoveryComponent(
            centralManager: centralManager,
            scanController: scanController,
            featureFlagProvider: featureFlagProvider,
            logger: logger,
            applicationGroup: applicationGroup
        )
    }
}
