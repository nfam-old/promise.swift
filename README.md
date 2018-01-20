# promise.swift

[![swift][swift-badge]][swift-url]
![platform][platform-badge]
[![build][travis-badge]][travis-url]
[![codecov][codecov-badge]][codecov-url]
[![coveralls][coveralls-badge]][coveralls-url]
![license][license-badge]

> An asynchronous computation library.

## Table of Contents

- [Install](#install)
- [API](#api)
    * [`Promise`](#promise)
        + [`Promise(executor(resolve,reject))`](#promiseexecutorresolvereject)
        + [`Promise(return)`](#promisereturn)
        + [`Promise(value)`](#promisevalue)
        + [`Promise(error)`](#promiseerror)
    * [`Promise.all`](#promiseall)
    * [`Promise.race`](#promiserace)
    * [`promise.then`](#promisethen)
    * [`promise.catch`](#promisecatch)
    * [`promise.finally`](#promisefinally)

## Install
```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/nfam/promise.swift.git", majorVersion: 0)
    ]
)
```

## API
API is similar to the standard Promise in [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise).

### `Promise`

#### `Promise(executor(resolve,reject))`
The `executor` function is executed immediately by the Promise implementation, passing `resolve` and `reject` functions (the executor is called before the Promise constructor even returns the created object). The `resolve` and `reject` functions, when called, resolve or reject the promise, respectively. The executor normally initiates some asynchronous work, and then, once that completes, either calls the `resolve` function to resolve the promise or else rejects it if an error occurred.
If an error is thrown in the executor function, the promise is rejected. The return value of the executor is ignored.
```swift
Promise<T> { resolve, reject in
    ...
    resolve($value)
}
Promise<T> { resolve, reject in
    ...
    reject($error)
}
Promise<T> { resolve, reject in
    ...
    throw $error
}
```

#### `Promise(return)`
The `return` function is to initiates some asynchronous work, and then, once that completes, returns a value to resolve the `Promise`. If an error thrown in the body function, the `Promise` is rejected.
```swift
Promise<T> {
    ...
    return $value
}
Promise<T> { $value }
Promise<T> {
    ...
    throw $error
}
```

#### `Promise(value)`
Returns a Promise object that is resolved with the given value.
```swift
Promise<T>(value: $value)
Promise(value: $value)
```

#### `Promise(error)`
Returns a Promise object that is rejected with the given reason.
```swift
Promise<T>(error: $error)
Promise(error: $error)
```

### `Promise.all`
Returns a promise that either fulfills when all of the promises in the iterable argument have fulfilled or rejects as soon as one of the promises in the iterable argument rejects. If the returned promise fulfills, it is fulfilled with an array of the values from the fulfilled promises in the same order as defined in the iterable. If the returned promise rejects, it is rejected with the reason from the first promise in the iterable that rejected. This method can be useful for aggregating results of multiple promises.
```swift
Promise.all(promise1, promise2, ...) -> Promise<[]>
Promise.all(resolved: Sequence<Promise>) -> Promise<[]>
```

### `Promise.race`
Returns a promise that fulfills or rejects as soon as one of the promises in the iterable fulfills or rejects, with the value or reason from that promise.
```swift
Promise.race(promise1, promise2, ...) -> Promise<[]>
Promise.race(resolved: Sequence<Promise>) -> Promise<[]>
```

### `promise.then`
Appends fulfillment and rejection handlers to the promise, and returns a new promise resolving to the return value of the called handler, or to its original settled value if the promise was not handled.
```swift
// onFulfilled
promise.then { value in
    ...
}

// onFulfilled, onRejected
promise.then(
    { value in  // fulfilled with value
        ...
    },
    { error in  // rejected with error
        ...
    }
)
```

### `promise.catch`
Appends a rejection handler callback to the promise, and returns a new promise resolving to the return value of the callback if it is called, or to its original fulfillment value if the promise is instead fulfilled. The Promise returned by catch() is rejected if onRejected throws an error or returns a Promise which is itself rejected; otherwise, it is resolved.
```swift
// onRejected
promise.catch { error in
    ...
}
```

### `promise.finally`
Appends a handler to the promise, and returns a new promise which is resolved when the original promise is resolved. The handler is called when the promise is settled, whether fulfilled or rejected.
> However, please note: a throw (or returning a rejected promise) in the finally callback will reject the new promise with that rejection reason.
```swift
// onFianlly
promise.finally {
    ...
}
```

[swift-url]: https://swift.org
[swift-badge]: https://img.shields.io/badge/Swift-3.1%20%7C%204.0-orange.svg?style=flat
[platform-badge]: https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS%20%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgray.svg?style=flat

[travis-badge]: https://travis-ci.org/nfam/promise.swift.svg
[travis-url]: https://travis-ci.org/nfam/promise.swift

[codecov-badge]: https://codecov.io/gh/nfam/promise.swift/branch/master/graphs/badge.svg
[codecov-url]: https://codecov.io/gh/nfam/promise.swift/branch/master

[coveralls-badge]: https://coveralls.io/repos/github/nfam/promise.swift/badge.svg
[coveralls-url]: https://coveralls.io/github/nfam/promise.swift

[license-badge]: https://img.shields.io/github/license/nfam/promise.swift.svg
