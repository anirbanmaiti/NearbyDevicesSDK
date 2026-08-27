//
//  AsyncSerialExecutor.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

import Foundation

protocol FlushableExecutor: Sendable {
   /// Sends an error to all queued and executing work.
   func flush(error: Error) async
}

extension AsyncSerialExecutor: FlushableExecutor {
    func flush(error: Error) async {
        self.flush(.failure(error))
    }
}

enum AsyncExecutorError: Error {
    case canceled
    case notExecutingWork
    case timeout
    case executorNotFound
}

/// Executes queued work serially, in the order they where added (FIFO). After work has started, this class will await
/// until the client completes it before taking on the next work.
actor AsyncSerialExecutor<Value: Sendable> {

    private struct QueuedWork {
        let id: UUID
        let block: @Sendable () async -> Void
        var continuation: CheckedContinuation<Value, Error>
        var isCanceled = false
    }

    private struct CurrentWork {
        let id: UUID
        let continuation: CheckedContinuation<Value, Error>
    }

    var isExecutingWork: Bool {
        self.currentWork != nil
    }

    /// Whether we're executing or have queued work.
    var hasWork: Bool {
        self.isExecutingWork || self.queue.count > 0
    }

    private var currentWork: CurrentWork?
    private var queue: [QueuedWork] = []

    /// Places work in the queue to be executed. If the queue is empty it will be executed. Otherwise it will
    /// get dequeued (and executed) when all previously queued work has finished.
    /// This function will await for specific timeout until the given block is executed and will resume after clients provide a Result or timeout occurs.
    /// - Note: No other work will be executed while there's a work in progress.
    func enqueue(
        timeout: TimeInterval? = nil,
        _ block: @Sendable @escaping () async -> Void
    ) async throws -> Value {
        do {
            return try await withThrowingTaskGroup(of: Value.self) { [weak self] group in
                guard let self else { throw AsyncExecutorError.canceled }
                group.addTask {
                    return try await self.enqueue(block)
                }
                if let timeout {
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        throw AsyncExecutorError.timeout
                    }
                }
                guard let result = try await group.next() else {
                    throw AsyncExecutorError.canceled
                }
                group.cancelAll()
                return result
            }
        } catch is CancellationError {
            throw AsyncExecutorError.canceled
        }
    }

    /// Places work in the queue to be executed. If the queue is empty it will be executed. Otherwise it will
    /// get dequeued (and executed) when all previously queued work has finished.
    /// This function will await until the given block is executed and will only resume after clients provide a Result
    /// - Note: No other work will be executed while there's a work in progress.
    func enqueue(
        _ block: @Sendable @escaping () async -> Void
    ) async throws -> Value {
        let queuedWorkID = UUID()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let work = QueuedWork(id: queuedWorkID, block: block, continuation: continuation)
                self.queue.append(work)
                self.scheduleDequeue()
            }
        } onCancel: {
            Task.detached { [weak self] in
                await self?.cancelWork(id: queuedWorkID)
            }
        }
    }

    /// Completes the current work with the given result and dequeues the next queued work.
    func setWorkCompletedWithResult(_ result: Result<Value, Error>) throws {
        defer {
            self.scheduleDequeue()
        }

        guard let currentWork = self.currentWork else {
            throw AsyncExecutorError.notExecutingWork
        }

        currentWork.continuation.resume(with: result)

        self.currentWork = nil
    }

    /// Sends the given result to all queued and executing work.
    func flush(_ result: Result<Value, Error>) {
        let queue = self.queue
        self.queue.removeAll()

        self.currentWork?.continuation.resume(with: result)
        self.currentWork = nil

        queue.forEach { $0.continuation.resume(with: result) }
    }

    private func scheduleDequeue() {
        Task.detached {
            await self.dequeueIfNecessary()
        }
    }

    /// Grabs the next available work from the queue. If it's not canceled, executes it. Otherwise sends a
    /// `AsyncSerialExecutor.canceled` error.
    private func dequeueIfNecessary() async {
        guard !self.isExecutingWork && !self.queue.isEmpty else { return }

        let queuedWork = self.queue.removeFirst()

        guard !queuedWork.isCanceled else {
            queuedWork.continuation.resume(throwing: AsyncExecutorError.canceled)
            self.scheduleDequeue()
            return
        }

        self.currentWork = CurrentWork(id: queuedWork.id, continuation: queuedWork.continuation)

        await queuedWork.block()
    }

    /// Cancels the work with the given ID. If the work is executing it will be immediately canceled. If it's queued,
    /// the work will get flagged and once its dequeued, it will get canceled without executing.
    private func cancelWork(id: UUID) {
        guard let currentWork = self.currentWork, currentWork.id == id else {
            self.markQueuedWorkAsCanceled(id: id)
            return
        }
        currentWork.continuation.resume(throwing: AsyncExecutorError.canceled)
        self.currentWork = nil
        self.scheduleDequeue()
    }

    private func markQueuedWorkAsCanceled(id: UUID) {
        guard let index = self.queue.firstIndex(where: { $0.id == id }) else { return }
        self.queue[index].isCanceled = true
    }
}
