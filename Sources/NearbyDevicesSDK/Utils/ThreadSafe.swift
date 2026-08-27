//
//  ThreadSafe.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// Enables thread safety as a property wrapper
///
/// When used, the wrapped property will automatically be accessed and modified
/// with the use of an `os_unfair_lock_t`
///
/// ```
/// @ThreadSafe private var names: [String] = []
/// ```
///
/// In the above code example, any accesses or modifications to the `names` property
/// will be performed behind the lock, ensuring that operations like one-line modifications,
/// eg. `names.append("John")` or `names[0] = "Ralph"` don't have the risk
/// of the having their underlying data modified between the read and the write.
@_spi(NearbyDevicesKitTest)
@propertyWrapper
public final class ThreadSafe<T> {
    private let lock = UnfairLock()
    private var value: T

    public var projectedValue: ThreadSafe<T> { self }

    public var wrappedValue: T {
        get {
            self.lock.lock(); defer { self.lock.unlock() }
            return self.value
        }
        _modify {
            self.lock.lock(); defer { self.lock.unlock() }
            yield &self.value
        }
    }

    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
}
