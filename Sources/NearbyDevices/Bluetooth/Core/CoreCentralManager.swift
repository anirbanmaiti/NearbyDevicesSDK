//
//  CoreCentralManager.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/18/26.
//

import Combine
import CoreBluetooth

// Wrapper for CBCentralManager. CoreCentralManager encapsulates CoreBluetooth dependencies.
final class CoreCentralManager: NSObject, CoreCentralManaging {

    // MARK: Properties

    static var authorization: CoreManagerAuthorization {
        CBCentralManager.authorization
    }

    weak var delegate: CoreCentralManagerDelegate?

    var isScanning: Bool {
        manager.isScanning
    }

    var isScanningPublisher: AnyPublisher<Bool, Never> {
        isScanningSubject.eraseToAnyPublisher()
    }

    var state: CoreManagerState {
        manager.state
    }

    func scanForPeripherals(withServices serviceUUIDs: [CoreUUID]? = nil, options: [String: Any]? = nil) {
        manager.scanForPeripherals(withServices: serviceUUIDs, options: options)
    }

    func stopScan() {
        manager.stopScan()
    }

    func connect(_ peripheral: CorePeripheralRepresentable, options: [String: Any]?) throws {
        guard let cbPeripheral = provide(for: peripheral) else {
            throw BluetoothError.peripheralNotFound
        }
        manager.connect(cbPeripheral)
    }

    func cancelPeripheralConnection(_ peripheral: CorePeripheralRepresentable) throws {
        guard let cbPeripheral = provide(for: peripheral) else {
            throw BluetoothError.peripheralNotFound
        }
        manager.cancelPeripheralConnection(cbPeripheral)
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CorePeripheralRepresentable] {
        manager.retrievePeripherals(withIdentifiers: identifiers).map(provide(for:))
    }

    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CoreUUID]) -> [CorePeripheralRepresentable] {
        manager.retrieveConnectedPeripherals(withServices: serviceUUIDs).map(provide(for:))
    }

    // MARK: Initialization

    /// Creates a CoreBluetoothCentralManager instance.
    /// - Parameters:
    ///   - dispatcher:  The dispatch queue on which the events will be dispatched.
    ///   - delegate: The delegate object that will receive central events.
    ///   - config: Config to create the options for the manager.
    init(
        dispatcher: DispatchQueue?,
        delegate: CoreCentralManagerDelegate?,
        bluetoothConfiguration: BluetoothManagerConfiguration,
        logger: NDLoggerProtocol?
    ) {
        self.dispatcher = dispatcher
        self.bluetoothConfiguration = bluetoothConfiguration
        self.delegate = delegate
        self.logger = logger
        super.init()
        addManagerObserver()
    }

    // MARK: Private
    private lazy var manager: CBCentralManager = {
        let cbCentralManager = CBCentralManager(delegate: self, queue: dispatcher, options: nil)
        return cbCentralManager
    }()

    private let dispatcher: DispatchQueue?
    private let bluetoothConfiguration: BluetoothManagerConfiguration
    private let logger: NDLoggerProtocol?
    private var isScanningSubject = PassthroughSubject<Bool, Never>()
    private let centralStateSubject = PassthroughSubject<CoreManagerState, Never>()
    private var observation: NSKeyValueObservation?
    /// A map of peripherals known to central manager.
    private var peripheralsBox = [UUID: CorePeripheral]()
    let peripheralsQueue = DispatchQueue(label: "com.itiam.nsdk.corecentralmanager", qos: DispatchQoS.default, attributes: .concurrent)

    /// Add observer for `\.CBCentralManager.isScanning`  and change `self.isScanning` correspondingly.
    private func addManagerObserver() {
        observation = manager.observe(\.isScanning, options: [.old, .new]) { [weak self] _, change in
            if let newVal = change.newValue {
                self?.isScanningSubject.send(newVal)
            }
        }
    }

    /// Provides `CorePeripheralRepresentable` for specified `CBPeripheral`.
    ///
    /// If it was previously created it returns that object, so that there can be only one `CorePeripheralRepresentable` per `CBPeripheral`.
    /// If not it creates new one. This cache is updated upon discovery or when retrievePeripherals or retrieveConnectedPeripherals is called.
    ///
    /// - Parameter peripheral: Peripheral for which to provide delegate wrapper
    /// - Returns: `CorePeripheralRepresentable` for specified peripheral.
    private func provide(for cbPeripheral: CBPeripheral) -> CorePeripheralRepresentable {
        peripheralsQueue.sync(flags: .barrier) {
            if let peripheral = peripheralsBox[cbPeripheral.identifier], cbPeripheral === peripheral.cbPeripheral {
                return peripheral
            }
            let newPeripheral = CorePeripheral(peripheral: cbPeripheral, logger: logger)
            peripheralsBox[cbPeripheral.identifier] = newPeripheral
            return newPeripheral
        }
    }

    /// Provides `CBPeripheral` for specified `CorePeripheralRepresentable` from the cache.
    private func provide(for peripheral: CorePeripheralRepresentable) -> CBPeripheral? {
        peripheralsQueue.sync {
            peripheralsBox[peripheral.identifier]?.cbPeripheral
        }
    }

    /// Resets periheral cache when bluetooth is not powered on.
    private func resetPeripheralCacheIfNeeded() {
        guard state != .poweredOn else { return }
        peripheralsQueue.sync(flags: .barrier) {
            peripheralsBox.removeAll()
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension CoreCentralManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger?.logDebug("centralManagerDidUpdateState \(central.state)", tag: .ble)
        resetPeripheralCacheIfNeeded()
        delegate?.didUpdateState(central: self)
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // A value of 127 is reserved and indicates the RSSI was not available.
        let rssi = RSSI.intValue == 127 ? nil : RSSI.intValue
        delegate?.didDiscover(peripheral: provide(for: peripheral), advertisementData: advertisementData, rssi: rssi)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger?.logDebug("didConnect \(peripheral)", tag: .ble)
        delegate?.didConnect(peripheral: provide(for: peripheral))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger?.logDebug("didDisconnectPeripheral \(peripheral). Error: \(String(describing: error)).", tag: .ble)
        delegate?.didDisconnectPeripheral(peripheral: provide(for: peripheral), error: error)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger?.logDebug("didFailToConnect \(peripheral). Error: \(String(describing: error)).", tag: .ble)
        delegate?.didFailToConnect(peripheral: provide(for: peripheral), error: error)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        logger?.logDebug("willRestoreState \(dict)", tag: .ble)
    }
}
