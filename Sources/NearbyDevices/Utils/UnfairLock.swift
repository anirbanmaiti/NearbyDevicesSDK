//
//  UnfairLock.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import os

/// A simple wrapper around `os_unfair_lock_t` to provide a nicer
/// interface to work with.
final class UnfairLock {
    public init() {
        self.pointer = .allocate(capacity: 1)
        self.pointer.initialize(to: os_unfair_lock())
    }

    deinit {
        self.pointer.deinitialize(count: 1)
        self.pointer.deallocate()
    }

    public func lock() {
        os_unfair_lock_lock(self.pointer)
    }

    public func unlock() {
        os_unfair_lock_unlock(self.pointer)
    }

    private let pointer: os_unfair_lock_t
}
