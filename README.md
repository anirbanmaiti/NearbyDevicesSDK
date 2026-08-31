# NearbyDevicesSDK

A Swift package for discovering nearby Bluetooth Low Energy (BLE) devices on iOS and macOS, built on Core Bluetooth with a modern Swift concurrency (async/await) API.

## Features

- **Simple async API** — a single `NearbyDevicesAPI` entry point for permission handling, Bluetooth state, and device discovery.
- **Live device stream** — observe nearby devices as a `CurrentValueStream<Set<DiscoveredDevice>>` that updates as devices appear, change, or go stale.
- **Automatic staleness handling** — devices older than a configurable `maxAge` are removed from the stream automatically.
- **Scan modes** — `ScanRequestReason.active` scans without duplicate filtering (useful for RSSI sampling); `.background` scans with duplicate filtering.
- **Swift 6 ready** — builds in the Swift 6 language mode with strict concurrency.
- **Testable by design** — Core Bluetooth types are abstracted behind protocols (`CoreCentralManaging`, `CorePeripheralRepresentable`, …) so the stack can be exercised without real hardware.

## Requirements

- iOS 17.2+ / macOS 13+
- Swift 6.3 toolchain (Xcode 26+)

## Installation

Add the package to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/anirbanmaiti/NearbyDevicesSDK.git", branch: "main")
]
```

Then add `NearbyDevicesSDK` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["NearbyDevicesSDK"]
)
```

## Usage

### Setup

Create a `NearbyDevicesGate`, the concrete implementation of `NearbyDevicesAPI`:

```swift
import NearbyDevicesSDK

struct MyFeatureFlags: NDFeatureFlagProviding {}

let nearbyDevices: NearbyDevicesAPI = NearbyDevicesGate(
    featureFlagProvider: MyFeatureFlags(),
    logger: nil, // or your own NDLoggerProtocol implementation
    applicationGroup: "group.com.example.myapp"
)
```

### Request Bluetooth permission

```swift
// Shows the system Bluetooth permission dialog the first time it is called.
await nearbyDevices.requestPermission()

// Observe authorization changes.
let authorization = await nearbyDevices.bluetoothAuthorization
print(authorization.value)
```

### Scan for nearby devices

```swift
// Start scanning. Pass a duration, or nil to scan until stopped manually.
try await nearbyDevices.search(reason: .active, duration: nil)

// Observe discovered devices; entries older than 30 seconds are dropped.
let devicesStream = await nearbyDevices.nearbyDevicesStream(maxAge: 30)
for await devices in devicesStream.stream {
    for device in devices {
        print(device.peripheralIdentifier, device.advertisement.rssi ?? "n/a")
    }
}

// Stop scanning when done.
await nearbyDevices.stopSearch(reason: .active)
```

`CurrentValueStream` also offers a Combine-style `sink` and synchronous access to the latest value via `.value`.

### Logging

Implement `NDLoggerProtocol` to route the package's logs into your own logging system:

```swift
struct MyLogger: NDLoggerProtocol {
    func log(_ tag: String, _ logLevel: LogLevel, _ message: String) {
        print("\(tag) [\(logLevel)] \(message)")
    }
}
```

## App configuration

Add the Bluetooth usage description to your app's `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to discover nearby devices.</string>
```

## Architecture

```
Sources/NearbyDevicesSDK
├── NearbyDevicesAPI.swift      // Public API surface
├── NearbyDevicesGate.swift     // Concrete entry point / composition root
├── Bluetooth/
│   ├── Central/                // BluetoothManager: CBCentralManager wrapper
│   ├── Core/                   // Protocol abstractions over Core Bluetooth
│   ├── Peripheral/             // BlePeripheral: CBPeripheral wrapper
│   └── ...                     // State, authorization, errors, scan requests
├── Discovery/
│   ├── ScanController/         // Coordinates and prioritizes scan requests
│   ├── DiscoveredDeviceCache   // Tracks devices and expires stale entries
│   └── NearbyDiscoveryComponent
└── Utils/                      // CurrentValueStream, async helpers, locks
```

- **`NearbyDevicesGate`** wires the components together and exposes the public API.
- **`BluetoothManager`** owns the `CBCentralManager` lifecycle, authorization, and state.
- **`ScanController`** serializes competing scan requests and applies per-reason scan settings.
- **`DiscoveredDeviceCache`** aggregates discovery events into the device stream and evicts stale devices.

## Testing

```
swift test
```

## License

This project is available under the MIT License. See [LICENSE](LICENSE) for details.
