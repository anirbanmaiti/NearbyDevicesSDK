//
//  CurrentValueStream.swift
//  NearbyDevices
//
//  Created by Anirban Maiti on 6/21/26.
//

@preconcurrency import Combine
import Foundation
/// An observer that wraps a single value and publishes a new element whenever the value changes.
///
/// Usages:
/// ```
/// struct BLEDevice {
/// var rssi: CurrentValueStream<Int?> {
///    CurrentValueStream(valueSubject: currentValueSubject)
/// }
/// var currentValueSubject = CurrentValueSubject<Int?, Never>(nil)
/// }
///
/// print(bleDevice.rssi.value)
/// let cancellable = bleDevice.rssi.sink { value in
///     print(value)
/// }
/// cancellable.cancel()
/// ```
public class CurrentValueStream<Element>: @unchecked Sendable where Element: Sendable {

    public typealias CompletionHandler = @Sendable () -> Void
    /// The value wrapped by this observer, published via `valueStream` as a new element whenever it changes.
    public var value: Element {
        valueSubject.value
    }

    /// Event stream.
    /// - Important: Stream will get deallocated if CurrentValueStream is not retained by the caller.
    public var stream: AsyncStream<Element> {
        valueSubject.stream
    }

    /// Consume the async sequence and pass the element's to a closure.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from `Task.currentPriority`.
    ///   - receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of the received value. Deallocation of the result will tear down the current value stream.
    public func sink(
        priority: TaskPriority? = nil,
        dropFirst: Bool = false,
        receiveValue: @Sendable @escaping (Element) async -> Void
    ) -> AnyCancellable {
        let task = valueSubject.dropFirst(dropFirst ? 1 : 0).stream.sink(priority: priority, receiveValue: receiveValue)
        let subscription = EventSubscription(task: task)
        subscription.target = self
        return AnyCancellable(subscription)
    }

    public func onCompletion(
        _ handler: @escaping CompletionHandler
    ) -> Self {
        completionHanders.append(handler)
        return self
    }

    // MARK: Initialization
    @available(*, deprecated, message: "Replaced with init(publisher:initialValue:)")
    public init(valueSubject: CurrentValueSubject<Element, Never>) {
        self.valueSubject = valueSubject
    }

    public init(
        publisher: AnyPublisher<Element, Never>,
        initialValue: Element
    ) {
        valueSubject = CurrentValueSubject<Element, Never>(initialValue)
        cancellable = publisher.sink(
            receiveCompletion: { [weak self] _ in
                self?.cancelStream()
            }, receiveValue: { [weak self] in
                self?.valueSubject.send($0)
            })
    }

    /// Instantiated using another AsyncStream.
    public init<S: AsyncSequence & Sendable>(sequence: S, initialValue: Element) where S.Element == Element {
        let subject = CurrentValueSubject<Element, Never>(initialValue)
        valueSubject = subject
        sequence.sink { [weak subject] in subject?.send($0) }
    }

    deinit {
        cancelStream()
    }

    // MARK: Private
    /// A subscription can only be cancelled once. The `streamIsCancelled` value
    /// is used to suppress a second call to cancel when the CurrentValueStream is deallocated,
    private func cancelStream() {
        guard streamIsCancelled == false else { return }
        streamIsCancelled = true
        completionHanders.forEach { $0() }
        completionHanders.removeAll()
    }

    private var valueSubject: CurrentValueSubject<Element, Never>
    private var streamIsCancelled = false
    private var cancellable: AnyCancellable?
    private var completionHanders = [CompletionHandler]()

    class EventSubscription: Cancellable {
        let uuid: UUID

        var target: CurrentValueStream?

        /// When our subscription was cancelled, we'll release the reference to our target
        /// and cancel the task to prevent any additional events from being sent to it.
        func cancel() {
            task.cancel()
            target = nil
        }

        init(task: Task<Void, Error>) {
            self.uuid = UUID()
            self.task = task
        }

        private let task: Task<Void, Error>
    }
}

// MARK: Hashable
extension CurrentValueStream.EventSubscription: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    public static func ==(_ lhs: CurrentValueStream.EventSubscription, _ rhs: CurrentValueStream.EventSubscription) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
