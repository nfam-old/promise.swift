//
//  Promise.swift
//
//  Created by Ninh on 21/09/2016.
//  Copyright © 2016 Ninh. All rights reserved.
//

import class Dispatch.DispatchQueue

// *****************************************
// API
//
// - Promise(func(resolve, reject))
// - Promise(value)
// - Promise(error)
// - Promise(body)
// - Promise.all(resolved)
// - Promise.race(promises)
//
// - promise.then
// - promise.catch
//
// *****************************************

/// The Promise object is used for asynchronous computations. A Promise
/// represents a value which may be available now, or in the future, or never.
public class Promise<T> {
    fileprivate let chain: Chain

    fileprivate init(chain: Chain) {
        self.chain = chain
    }
}

extension Promise {

    /// Creates a `Promise` with a function that is passed the arguments resolve and reject.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The default `DispatchQueue.global()` will be employed instead.
    ///
    /// - Parameter body:
    ///   A function to initiates some asynchronous work, and then, once
    ///   that completes, either calls the resolve function to resolve
    ///   the `Promise` or else rejects it if an error occurred. If an error
    ///   is thrown in the body function, the `Promise` is rejected.
    public convenience init(
        in queue: DispatchQueue? = nil,
        execute body: @escaping (@escaping (T) -> Void, @escaping (Error) -> Void) throws -> Void
    ) {
        self.init(chain: Chain())
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { _, completion in
            var state = State.ready
            do {
                try body(
                    { value in
                        if state != .ready {
                            fatalError("Promise is already settled.")
                        }
                        else {
                            state = .resolved
                            completion(Result(value: value))
                        }
                    },
                    { error in
                        if state != .ready {
                            fatalError("Promise is already settled.")
                        }
                        else {
                            state = .rejected
                            completion(Result(error: error))
                        }
                    }
                )
            }
            catch {
                if state != .ready {
                    fatalError("Promise is already settled.")
                }
                else {
                    state = .throwed
                    completion(Result(error: error))
                }
            }
        })
    }

    /// Creates a `Promise` with a function that returns a value to resolve or throws error to reject.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The default `DispatchQueue.global()` will be employed instead.
    ///
    /// - Parameter body:
    ///   A function to initiates some asynchronous work, and then, once
    ///   that completes, returns a value to resolve the `Promise`. If an
    ///   error thrown in the body function, the `Promise` is rejected.
    public convenience init(
        in queue: DispatchQueue? = nil,
        execute body: @escaping () throws -> T
    ) {
        self.init(chain: Chain())
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { _, completion in
            do {
                let value = try body()
                completion(Result(value: value))
            }
            catch {
                completion(Result(error: error))
            }
        })
    }

    /// Creates a `Promise` that is resolved with a given value.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The default `DispatchQueue.global()` will be employed instead.
    ///
    /// - Parameter value: A resolved `Promise` value.
    public convenience init(in queue: DispatchQueue? = nil, value: T) {
        self.init(chain: Chain())
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { _, completion in
            completion(Result(value: value))
        })
    }

    /// Creates a `Promise` that is rejected with a given error.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The default `DispatchQueue.global()` will be employed instead.
    ///
    /// - Parameter error: A rejected `Promise` reason.
    public convenience init(in queue: DispatchQueue? = nil, error: Error) {
        self.init(chain: Chain())
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { _, completion in
            completion(Result(error: error))
        })
    }
}

extension Promise {

    /// Returns a `Promise` that either resolves when all of the promises
    /// in the iterable argument have resolved or rejects as soon as one
    /// of the promises in the iterable argument rejects.
    ///
    /// * If the returned `Promise` resolves, it is resolved with an array
    ///   of the values from the resolved promises in same order as defined
    ///   in the iterable.
    ///
    /// * If the returned `Promise` rejects, it is rejected with the reason
    ///   from the first `Promise` in the iterable that rejected.
    ///
    /// This method can be useful for aggregating results of multiple promises.
    ///
    /// - Parameter promises: Promises that will resolve or reject.
    ///
    /// - Returns: A `Promise`.
    public class func all<S: Sequence>(resolved promises: S) -> Promise<[T]>
        where S.Iterator.Element == Promise
    {
        let promises = Array(promises)
        if promises.isEmpty {
            return Promise<[T]>(value: [T]())
        }

        let promise = Promise<[T]>(chain: Chain())
        promise.chain.append(node: Node(in: promise.chain.queue) { _, completion in
            var results = [(offset: Int, value: T)]()
            var finised = false
            for item in promises.enumerated() {
                item.element.then(in: seriesQueue) { value in
                    if !finised {
                        results.append((offset: item.offset, value: value))
                        if results.count == promises.count {
                            finised = true
                            var values = [T]()
                            for offset in 0 ..< results.count {
                                for result in results where result.offset == offset {
                                    values.append(result.value)
                                }
                            }
                            completion(Result(value: values))
                        }
                    }
                }
                .catch(in: seriesQueue) { error -> Void in
                    if !finised {
                        finised = true
                        completion(Result(error: error))
                    }
                }
            }
        })
        return promise
    }

    /// Returns a `Promise` that either resolves when all of the gvien promises
    /// in the iterable argument have resolved or rejects as soon as one
    /// of the promises in the iterable argument rejects.
    ///
    /// * If the returned `Promise` resolves, it is resolved with an array
    ///   of the values from the resolved promises in same order as defined
    ///   in the iterable.
    ///
    /// * If the returned `Promise` rejects, it is rejected with the reason
    ///   from the first `Promise` in the iterable that rejected.
    ///
    /// This method can be useful for aggregating results of multiple promises.
    ///
    /// - Parameter promises: Promises that will resolve or reject.
    ///
    /// - Returns: A `Promise`.
    public class func all(_ promises: Promise<T>...) -> Promise<[T]> {
        return all(resolved: promises)
    }
}

extension Promise {

    /// Returns a `Promise` that fulfills or rejects as soon as one of
    /// the promises in the iterable fulfills or rejects, with the value or
    /// reason from that `Promise`.
    ///
    /// - Parameter promises: Promises that will resolve or reject.
    public class func race<S: Sequence>(promises: S) -> Promise<T>
        where S.Iterator.Element == Promise
    {
        let promises = Array(promises)
        guard !promises.isEmpty else {
            fatalError("Cannot race with an empty array of promises.")
        }
        let promise = Promise<T>(chain: Chain())
        promise.chain.append(node: Node(in: promise.chain.queue) { _, completion in
            var finised = false
            for p in promises {
                p.then(in: seriesQueue) { value in
                    if !finised {
                        finised = true
                        completion(Result(value: value))
                    }
                }
                .catch(in: seriesQueue) { error -> Void in
                    if !finised {
                        finised = true
                        completion(Result(error: error))
                    }
                }
            }
        })
        return promise
    }

    /// Returns a `Promise` that fulfills or rejects as soon as one of
    /// the given promises fulfills or rejects, with the value or
    /// reason from that `Promise`.
    ///
    /// - Parameter promises: Promises that will resolve or reject.
    public class func race(_ promises: Promise<T>...) -> Promise<T> {
        return race(promises: promises)
    }
}

extension Promise {

    /// Appends fulfillment handler to the `Promise`, and returns a new `Promise`
    /// resolving to the return value of the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter fulfillment: A fulfillment handler function.
    ///
    /// - Returns: A `Promise`.
    public func then<U>(
        in queue: DispatchQueue? = nil,
        fulfillment: @escaping (T) throws -> U
    ) -> Promise<U> {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if result.error != nil {
                completion(result)
            }
            else {
                do {
                    if U.self == Void.self {
                        _ = try fulfillment(result.value as! T)
                        completion(voidResult)
                    }
                    else {
                        let value = try fulfillment(result.value as! T)
                        completion(Result(value: value))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
        })
        return Promise<U>(chain: self.chain)
    }

    /// Appends fulfillment and rejection handlers to the `Promise`, and returns a new `Promise`
    /// resolving to the return value of the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter fulfillment: A fulfillment handler function.
    ///
    /// - Parameter rejection: An optional rejection handler function.
    ///
    /// - Returns: A `Promise`.
    public func then<U>(
        in queue: DispatchQueue? = nil,
        fulfillment: @escaping (T) throws -> U,
        rejection: @escaping (Error) throws -> U
    ) -> Promise<U> {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if let error = result.error {
                do {
                    if U.self == Void.self {
                        _ = try rejection(error)
                        completion(voidResult)
                    }
                    else {
                        let value = try rejection(error)
                        completion(Result(value: value))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
            else {
                do {
                    if U.self == Void.self {
                        _ = try fulfillment(result.value as! T)
                        completion(voidResult)
                    }
                    else {
                        let value = try fulfillment(result.value as! T)
                        completion(Result(value: value))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
        })
        return Promise<U>(chain: self.chain)
    }

    /// Appends fulfillment handlers to the `Promise`, and returns the `Promise`
    /// from the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter body: A handler function.
    ///
    /// - Returns: A `Promise`.
    public func then<U>(
        in queue: DispatchQueue? = nil,
        fulfillment: @escaping (T) throws -> Promise<U>
    ) -> Promise<U> {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if result.error != nil {
                completion(result)
            }
            else {
                do {
                    let p = try fulfillment(result.value as! T)
                    p.then { value in
                        completion(Result(value: value))
                    }
                    .catch { error in
                        completion(Result(error: error))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
        })
        return Promise<U>(chain: self.chain)
    }

    /// Appends fulfillment handlers to the `Promise`, and returns the `Promise`
    /// from the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter body: A handler function.
    ///
    /// - Returns: A `Promise`.
    public func then<U>(
        in queue: DispatchQueue? = nil,
        fulfillment: @escaping (T) throws -> Promise<U>,
        rejection: @escaping (Error) throws -> Promise<U>
    ) -> Promise<U> {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if let error = result.error {
                do {
                    let p = try rejection(error)
                    p.then { value in
                        completion(Result(value: value))
                    }
                    .catch { error in
                        completion(Result(error: error))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
            else {
                do {
                    let p = try fulfillment(result.value as! T)
                    p.then { value in
                        completion(Result(value: value))
                    }
                    .catch { error in
                        completion(Result(error: error))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
        })
        return Promise<U>(chain: self.chain)
    }
}

extension Promise {

    /// Appends a rejection handler callback to the `Promise`, and returns
    /// the `Promise` itself.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter rejection: A handler function.
    ///
    /// - Returns: The current `Promise` itself.
    @discardableResult
    public func `catch`(
        in queue: DispatchQueue? = nil,
        rejection: @escaping (Error) throws -> Void
    ) -> Promise {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if let e = result.error {
                do {
                    try rejection(e)
                    completion(voidResult)
                }
                catch {
                    completion(Result(error: error))
                }
            }
            else {
                completion(result)
            }
        })
        return self
    }

    /// Appends a rejection handler callback to the `Promise`, and returns
    /// the `Promise` from the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter rejection: A handler function.
    ///
    /// - Returns: The `Promise` from the called handler.
    public func `catch`(
        in queue: DispatchQueue? = nil,
        rejection: @escaping (Error) throws -> Promise
    ) -> Promise {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            if let e = result.error {
                do {
                    let p = try rejection(e)
                    p.then { value in
                        completion(Result(value: value))
                    }
                    .catch { error in
                        completion(Result(error: error))
                    }
                }
                catch {
                    completion(Result(error: error))
                }
            }
            else {
                completion(result)
            }
        })
        return self
    }
}

extension Promise {

    /// Appends a handler handler callback to the `Promise`, and returns
    /// the `Promise` itself.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter finalizing: A handler function.
    ///
    /// - Returns: The current `Promise` itself.
    @discardableResult
    public func `finally`(
        in queue: DispatchQueue? = nil,
        finalizing: @escaping () throws -> Void
    ) -> Promise {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            do {
                try finalizing()
                completion(result)
            }
            catch {
                completion(Result(error: error))
            }
        })
        return self
    }

    /// Appends a handler handler callback to the `Promise`, and returns
    /// the `Promise` from the called handler.
    ///
    /// - Parameter queue:
    ///   An optional `DispatchQueue` to execute in. If it is not given,
    ///   The current `DispatchQueue` in the chain will be employed instead.
    ///
    /// - Parameter finalizing: A handler function.
    ///
    /// - Returns: The `Promise` from the called handler.
    @discardableResult
    public func `finally`(
        in queue: DispatchQueue? = nil,
        finalizing: @escaping () throws -> Promise
    ) -> Promise {
        self.chain.append(node: Node(in: queue ?? self.chain.queue) { result, completion in
            do {
                let p = try finalizing()
                p.then { value in
                    completion(result)
                }
                .catch { error in
                    completion(Result(error: error))
                }
            }
            catch {
                completion(Result(error: error))
            }
        })
        return self
    }
}

// ********************************************************
// PRIVATE
// ********************************************************
private let seriesQueue = DispatchQueue(label: "Promise.series")
private let voidValue: Any = ()
private let voidResult = Result(value: voidValue)

private enum State {
    case ready
    case resolved
    case rejected
    case throwed
}

private struct Result {
    let value: Any
    let error: Error?

    init(value: Any) {
        self.value = value
        self.error = nil
    }

    init(error: Error) {
        self.value = voidValue
        self.error = error
    }
}

private class Node {
    let queue: DispatchQueue
    let exec: (Result, @escaping (Result) -> Void) -> Void
    var next: Node?

    init(in queue: DispatchQueue, execute body: @escaping (Result, @escaping (Result) -> Void) -> Void) {
        self.queue = queue
        self.exec = body
    }
}

private class Chain {
    var queue: DispatchQueue
    var head: Node?
    var tail: Node?
    var result: Result

    init() {
        self.queue = DispatchQueue.global()
        self.result = voidResult
    }

    func append(node: Node) {
        seriesQueue.async {
            self.queue = node.queue
            if let tail = self.tail {
                tail.next = node
                self.tail = node
            }
            else {
                self.head = node
                self.tail = node
                self.tick()
            }
        }
    }

    private func tick() {
        if let node = self.head {
            node.queue.async {
                node.exec(self.result) { result in
                    seriesQueue.async {
                        self.result = result
                        self.head = self.head!.next
                        if self.head != nil {
                            self.tick()
                        }
                        else {
                            self.tail = nil
                        }
                    }
                }
            }
        }
    }
}
