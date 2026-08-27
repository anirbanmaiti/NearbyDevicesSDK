//
//  AsyncMapReduce.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation
public extension Sequence {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            if let trensformed = try await transform(element) {
                values.append(trensformed)
            }
        }
        return values
    }

    func asyncReduce<Result>(_ initialResult: Result, _ nextPartialResult: ((inout Result, Element) async throws -> Void)) async rethrows -> Result {
        var result = initialResult
        for element in self {
            try await nextPartialResult(&result, element)
        }
        return result
    }

    func asyncFirst(where predicate: (Element) async throws -> Bool) async rethrows -> Element? {
        for element in self {
            if try await predicate(element) {
                return element
            }
        }
        return nil
    }

    /// Calls the given concurrent closure on each element in the sequence in the same order
    /// as a `for`-`in` loop.
    ///
    /// Using the `forEach` method is distinct from a `for`-`in` loop in two
    /// important ways:
    ///
    /// - Parameter body: A concurrent closure that takes an element of the sequence as a
    ///   parameter.
    @inlinable func asyncForEach(_ body: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await body(element)
        }
    }
}
