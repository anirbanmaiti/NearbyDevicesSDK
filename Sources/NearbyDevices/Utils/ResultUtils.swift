//
//  ResultUtils.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

struct ResultUtils {
    static func result<T>(for value: T, error: Error?) -> Result<T, Error> {
        guard let error else {
            return .success(value)
        }
        return .failure(error)
    }

    static func result<T>(for value: T, error: Error?, resultingError: Error) -> Result<T, Error> {
        guard error != nil else {
            return .success(value)
        }
        return .failure(resultingError)
    }
}
