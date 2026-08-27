import Combine
import Foundation
import os.log

// MARK: -
public final class NearbyDevicesGate: NearbyDevicesAPI, @unchecked Sendable {
    
    // MARK: - API
    public var bluetoothState: CurrentValueStream<BluetoothState> {
        get async {
            await centralManager.bluetoothState
        }
    }

    public var bluetoothAuthorization: CurrentValueStream<BluetoothAuthorization> {
        get async {
            await centralManager.authorization
        }
    }

    public func requestPermission() async {
        await initializeBluetooth()
    }

    public func nearbyDevicesStream(maxAge: TimeInterval) async -> CurrentValueStream<Set<DiscoveredDevice>> {
        await discoveryComponent.nearbyDevicesStream(maxAge: maxAge)
    }

    public func search(reason: ScanRequestReason, duration: TimeInterval? = nil) async throws {
        try await discoveryComponent.search(reason: reason, duration: duration)
    }

    public func stopSearch(reason: ScanRequestReason) async {
        await discoveryComponent.stopSearch(reason: reason)
    }
    
    // MARK: - Initialization
    /// Creates a NearbyDevices Instance.
    /// - Parameters:
    ///    - featureFlagProvider: ND related feature flags provider .
    ///    - logger: Object to write logs
    ///    - userDefaults: UserDefaults instance
    ///    - applicationGroup: applicationGroup for initializing coredata container
    public init(
        featureFlagProvider: NDFeatureFlagProviding,
        logger: NDLoggerProtocol?,
        userDefaults: UserDefaults = .standard,
        applicationGroup: String
    ) {
        self.logger = logger
        self.featureFlagProvider = featureFlagProvider
        self.userDefaults = userDefaults
        self.applicationGroup = applicationGroup

        logger?.logDebug("NearbyDevicesGate: init")

        _ = centralManager
        _ = discoveryComponent

        bootstrapBluetoothIfAuthorized()
    }

    private func bootstrapBluetoothIfAuthorized() {
        let centralManager: any BluetoothManaging = self.centralManager
        Task {
            if await centralManager.authorization.value != .notDetermined {
                let config = BluetoothManagerConfiguration(restorationEnabled: false)
                await centralManager.initializeBluetooth(config: config)
            }
        }
    }

    private func initializeBluetooth() async {
        let config = BluetoothManagerConfiguration(restorationEnabled: false)
        await centralManager.initializeBluetooth(config: config)
    }

    deinit {
        logger?.logDebug("NearbyDevicesGate: deinit")
    }

    // MARK: - Internal
    internal var logger: NDLoggerProtocol?
    internal let featureFlagProvider: NDFeatureFlagProviding
    internal let userDefaults: UserDefaults
    internal let applicationGroup: String

    // MARK: Bluetooth
    internal lazy var centralManager: BluetoothManaging = makeBluetoothManager()
    internal lazy var scanController: ScanControlling = makeScanController()
    internal lazy var discoveryComponent: NearbyDiscoveryComponent = makeNDDiscoveryComponent()

    // MARK: Logger
    static let ndLogger = Logger(
        subsystem: Bundle(for: NearbyDevicesGate.self).bundleIdentifier ?? "",
        category: "ND"
    )
}

/// Namespace for NoOp classes used for disabled features.
enum NoOpAdapter {}
