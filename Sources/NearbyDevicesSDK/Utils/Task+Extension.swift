//
//  Task+Extension.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

public extension Task where Failure == Error {
    /// - Parameter set: The set in which to store this ``Task``.
    func store(in set: inout Set<Task<Success, Failure>>) {
        set.insert(self)
    }

    /// Launch task after delay
    static func delayed(
        byTimeInterval delayInterval: TimeInterval,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: priority) {
            let delay = UInt64(delayInterval * 1_000_000_000)
            try await Task<Never, Never>.sleep(nanoseconds: delay)
            return try await operation()
        }
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
