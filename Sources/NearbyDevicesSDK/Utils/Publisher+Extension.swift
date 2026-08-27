//
//  Publisher+Extension.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Combine

extension Publisher where Failure == Never, Output: Sendable {
    public var stream: AsyncStream<Output> {
        AsyncStream { continuation in
            let cancellable = sink { _ in
                continuation.finish()
            } receiveValue: { value in
                continuation.yield(value)
            }
            let box = UncheckedSendableBox(cancellable)
            continuation.onTermination = { _ in
                box.value.cancel()
            }
        }
    }
}

private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
