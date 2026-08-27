//
//  RequestHandle.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// A handle to request that can be used to cancel the request.
/// A reference to this handle must be held to prevent the request from being deallocated and cancelled.
public protocol RequestHandling: AnyObject, Sendable {
    /// Cancels the request.
    func cancel() async

    /// Leaks the request such that it won't be cancelled on deallocation
    func leak() async

    var isReleased: Bool { get async }
}

/// Delegate to notify release of the handle
protocol RequestHandleDelegate: AnyObject, Sendable {
    func requestHandleWasReleased(with uuid: UUID) async
}

/// Request Handle that can be used to remove request from the controller/manager.
actor RequestHandle: RequestHandling {

    // MARK: API
    func cancel() async {
        guard !isReleased else { return }

        isReleased = true
        await delegate?.requestHandleWasReleased(with: requestID)
    }

    func leak() {
        leaked = true
    }

    // MARK: Initialization
    init(requestID: UUID, delegate: RequestHandleDelegate?) {
        self.requestID = requestID
        self.delegate = delegate
    }

    deinit {
        guard !isReleased, !leaked else { return }
        Task { [delegate, requestID] in
            await delegate?.requestHandleWasReleased(with: requestID)
        }
    }

    // MARK: Private
    private let requestID: UUID
    private weak var delegate: RequestHandleDelegate?
    private(set) var isReleased = false
    private var leaked: Bool = false
}

extension RequestHandle: Equatable {
    static func == (lhs: RequestHandle, rhs: RequestHandle) -> Bool {
        lhs.requestID == rhs.requestID
    }
}
extension RequestHandle: @preconcurrency CustomStringConvertible {
    var description: String {
        return "\(String(describing: type(of: self))) id=\(requestID)"
    }
}
