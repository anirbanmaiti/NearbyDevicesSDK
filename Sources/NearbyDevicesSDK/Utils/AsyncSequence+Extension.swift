//
//  AsyncSequence+Extension.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation
public extension AsyncSequence {
    /// Consume the async sequence and pass the element's to a closure.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from `Task.currentPriority`.
    ///   - receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A task instance.
    @discardableResult
    func sink(
        priority: TaskPriority? = nil,
        receiveValue: @Sendable @escaping (Element) async -> Void
    ) -> Task<Void, Error> where Self: Sendable {
        Task(priority: priority) {
            for try await element in self {
                try Task.checkCancellation()
                await receiveValue(element)
            }
        }
    }
}
