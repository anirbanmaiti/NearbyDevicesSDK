//
//  NearbyDevicesAPI.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 4/11/26.
//
import Foundation

public protocol NearbyDevicesAPI {
    /// Bluetooth authorization current value observer.
    /// If authorization is `notDetermined`, invoke `requestPermission`
    var bluetoothAuthorization: CurrentValueStream<BluetoothAuthorization> { get async }

    /// Bluetooth state current value observer.
    var bluetoothState: CurrentValueStream<BluetoothState> { get async }

    /// Requests Bluetooth authorization. (iOS will display Bluetooth Permissions dialog when called first time after fresh install.)
    func requestPermission() async

    /// Returns CurrentValueStream that publishes a Set of nearby devices as a Set<DiscoveredDevice>. This Publisher will publish on each change such as a new device being discovered or as devices become stale
    /// - Parameters:
    ///   - maxAge: The "max age" of a discovered device. For example a value of 30 here will remove devices that are 30 seconds old.
    func nearbyDevicesStream(maxAge: TimeInterval) async -> CurrentValueStream<Set<DiscoveredDevice>>

    /// Starts the bluetooth scans. The results can be obtained by subscribing to the result of getNearbyDevicesStream()
    /// - Parameters:
    ///   - reason: Purpose of the scan request. enum ScanRequestReason maps to the corresponding set of scan ServiceUUIDs, duplicate filtering, and scan priority.
    ///   - duration: The time duration of the scan. If nil then the scan will continue to scan until manually stopped
    /// - Throws: `NDError.scanningRequestAlreadyInProgress`
    func search(reason: ScanRequestReason, duration: TimeInterval?) async throws

    /// Stops the search for nearby bluetooth devices with the given search reason, if one is running.
    /// - Parameters:
    ///   - reason: Purpose of the scan requested.
    func stopSearch(reason: ScanRequestReason) async

}
