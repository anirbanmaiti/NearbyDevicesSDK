//
//  BluetoothAccessAPI.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import CoreBluetooth
import Foundation

/// The various permissions that can be requested
public enum PermissionRequest {
    case bluetooth
}

/// The basic permissions state, primarily either granted or not
public enum PermissionAuthState {
    case notDetermined
    case granted
    case denied
}

/// The specific permissions result returned by the OS
public enum OSPermissionsResult {
    case bluetooth(CBManagerAuthorization)
}

/// The results of the permissions request
public struct PermissionResult {
    public let request: PermissionRequest
    public let authState: PermissionAuthState
    public let osResult: OSPermissionsResult

    public init(request: PermissionRequest, authState: PermissionAuthState, osResult: OSPermissionsResult) {
        self.request = request
        self.authState = authState
        self.osResult = osResult
    }
}

/// Permissions request delegate to watch permission request changes
public protocol PermissionsUtilDelegate {

    /// Called when the permission state changes
    func permissionsDidChange(results: [PermissionResult])

    /// Called to open url
    func openURL(_ url: URL)
}

public protocol PermissionsUtil {

    /// Allows the app to listen for permissions results
    var delegate: PermissionsUtilDelegate? { get set }

    /// Requests permissions that are not already granted
    ///
    /// If the permissions sate in the requests has not been granted, request permissions
    ///
    func checkPermissionStateAndRequestPermissions(requests: [PermissionRequest]) -> [PermissionResult]

    /// Returns the permissions state for each permissions given
    func getPermissionState(permissions: [PermissionRequest]) -> [PermissionResult]

    /// A convenience function that returns the permission state for a single permissions
    func getPermissionState(permission: PermissionRequest) -> PermissionResult

    /// A function that opens the app's settings screen in the Settings app
    func launchAppSettingsScreen()

    /// A function that requests a set of permissions
    ///
    /// Permissions changes from the requests will call the delegate's onPermissionsChange function
    ///
    func requestPermissions(request: [PermissionRequest])
}

/// Permissions request delegate to watch permission request changes
public protocol BluetoothUtilDelegate {

    /// Called when the permission state changes
    func permissionsDidChange(result: PermissionResult)
}

public protocol BluetoothUtil {

    /// Allows the app to listen for permissions results
    var delegate: BluetoothUtilDelegate? { get set }

    /// Access bluetooth in an attempt to request permissions
    ///
    /// This will bring up the OS's bluetooth request alert if it has not already been granted, denied, or restricted
    ///
    func requestBluetoothAccess()

    /// Returns true if the device supports Bluetooth
    ///
    /// This function will bring up the OS's bluetooth permissions dialog if the permissions have not been
    /// set granted or denied yet
    ///
    func doesDeviceSupportBluetooth() -> Bool
}
