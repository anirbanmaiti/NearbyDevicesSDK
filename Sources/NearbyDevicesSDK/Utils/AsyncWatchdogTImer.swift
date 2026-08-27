//
//  AsyncWatchdogTImer.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

/// AsyncWatchdogTimerDelegate is for handling timeouts in asynchronous tasks. This is used by the AsyncWatchdogTimer
/// to notify it's delegate that the time has finished and that presumably some action can now be performed
public protocol AsyncWatchdogTimerDelegate: AnyObject, Sendable {
    /// This delegate function is called when the timer times out.
    func asyncWatchdogTimerDidTimeout(_ timer: AsyncWatchdogTimer) async
}

/// A class that provides a timer for tracking timeouts in asynchronous tasks. The timer is restarted upon "kicking" the watchdog.
public final class AsyncWatchdogTimer: @unchecked Sendable {
    /// The delegate that will be notified when the timer times out.
    public weak var delegate: AsyncWatchdogTimerDelegate? {
        get {
            lock.lock(); defer { lock.unlock() }
            return _delegate
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _delegate = newValue
        }
    }

    public var interval: TimeInterval {
        get {
            lock.lock(); defer { lock.unlock() }
            return _interval
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _interval = newValue
        }
    }

    /// Initializes a new AsyncWatchdogTimer with the specified timeout interval.
    /// - Parameter interval: The timeout interval in seconds.
    public init(interval: TimeInterval) {
        self._interval = interval
    }

    /// Starts or restarts the timer.
    public func kick() {
        lock.lock()
        task?.cancel()
        let currentInterval = _interval
        task = Task { [weak self] in
            // Wait for the specified interval.
            try? await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))

            // Check if the task was cancelled
            guard !Task.isCancelled, let self else { return }

            // Notify the delegate that the timer has timed out.
            await self.delegate?.asyncWatchdogTimerDidTimeout(self)
        }
        lock.unlock()
    }

    /// Cancels the current timer task if it exists.
    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        task?.cancel()
    }

    deinit {
        task?.cancel()
    }

    private let lock = UnfairLock()
    private weak var _delegate: AsyncWatchdogTimerDelegate?
    private var _interval: TimeInterval
    private var task: Task<Void, Never>?
}
