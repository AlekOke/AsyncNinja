//
//  Copyright (c) 2016-2017 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Dispatch

// MARK: - Brief

/// This file contains 8 public methods that are product of three factors
/// - result handling: regular or flattening
/// - contextual: yes or no
/// - block scheduling: immediate or delayed

// MARK: - future makers: non-contextual, immediate block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func future<T>(executor: Executor = .primary,
                   block: @escaping () throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfBlock_Success
  // Test: FutureTests.testMakeFutureOfBlock_Failure
  let promise = Promise<T>()
  executor.execute { [weak promise] in
    guard nil != promise else { return }
    let value = fallible(block: block)
    promise?.complete(with: value)
  }
  return promise
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - block: is block to perform. Return from block will cause returned future to complete with future. Throw from block will returned future to complete with failure
/// - Returns: future
public func flatFuture<T>(executor: Executor = .primary,
                       block: @escaping () throws -> Future<T>) -> Future<T> {
  let promise = Promise<T>()
  executor.execute { [weak promise] in
    guard let promise = promise else { return }
    do { promise.complete(with: try block()) }
    catch { promise.fail(with: error) }
  }
  return promise
}

// MARK: - future makers: contextual, immediate block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from
///     a weak reference of context passed to method
/// - Returns: future
public func future<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                   block: @escaping (_ strongContext: U) throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextDead

  let promise = Promise<T>()
  (executor ?? context.executor)
    .execute { [weak promise, weak context] in
      guard nil != promise else { return }

      if let context = context {
        let value = fallible { try block(context) }
        promise?.complete(with: value)
      } else {
        promise?.cancelBecauseOfDeallocatedContext()
      }
  }

  context.addDependent(finite: promise)

  return promise
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - block: is block to perform. Return from block will cause
///     returned future to complete with future.
///     Throw from block will complete returned future with failure.
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func flatFuture<T, C: ExecutionContext>(context: C,
                       executor: Executor? = nil,
                       block: @escaping (_ strongContext: C) throws -> Future<T>) -> Future<T> {
  let promise = Promise<T>()
  (executor ?? context.executor)
    .execute { [weak promise, weak context] in
      guard nil != promise else { return }

      if let context = context {
        do {
          let futureResult = try block(context)
          promise?.complete(with: futureResult)
        } catch {
          promise?.fail(with: error)
        }
      } else {
        promise?.cancelBecauseOfDeallocatedContext()
      }
  }

  context.addDependent(finite: promise)

  return promise
}

// MARK: - future makers: non-contextual, delayed block scheduling

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete successfuly.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func future<T>(executor: Executor = .primary,
                   after timeout: Double,
                   cancellationToken: CancellationToken? = nil,
                   block: @escaping () throws -> T
  ) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Success
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Failure
  return promise(executor: executor,
                 after: timeout,
                 cancellationToken: cancellationToken,
                 block: block)
}

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause
///     returned future to complete with future.
///     Throw from block will returned future to complete with failure
/// - Returns: future
public func flatFuture<T>(executor: Executor = .primary,
                       after timeout: Double,
                       cancellationToken: CancellationToken? = nil,
                       block: @escaping () throws -> Future<T>
  ) -> Future<T> {
  return flatPromise(executor: executor,
                     after: timeout,
                     cancellationToken: cancellationToken,
                     block: block)
}

// MARK: - future makers: contextual, delayed block scheduling

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause returned
///     future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func future<T, C: ExecutionContext>(context: C,
                   executor: Executor? = nil,
                   after timeout: Double,
                   cancellationToken: CancellationToken? = nil,
                   block: @escaping (_ strongContext: C) throws -> T
  ) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead
  let promiseValue = promise(executor: executor ?? context.executor, after: timeout, cancellationToken: cancellationToken) { [weak context] () -> T in
    guard let context = context
      else { throw AsyncNinjaError.contextDeallocated }

    return try block(context)
  }

  context.addDependent(finite: promiseValue)

  return promiseValue
}

/// Makes future that will complete depending on block's return/throw
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - after: is `Double` timeout in seconds to schedule block after
///   - cancellationToken: is optional `CancellationToken` able to cancel
///     execution of block and fail returned future with `AsyncNinjaError.cancelled`
///   - block: is block to perform. Return from block will cause returned
///     future to complete successfuly.
///     Throw from block will returned future to complete with failure
///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
/// - Returns: future
public func flatFuture<T, C: ExecutionContext>(context: C,
                       executor: Executor? = nil,
                       after timeout: Double,
                       cancellationToken: CancellationToken? = nil,
                       block: @escaping (_ strongContext: C) throws -> Future<T>
  ) -> Future<T> {
  let executor_ = executor ?? context.executor
  let promiseValue = flatPromise(executor: executor_,
                                 after: timeout,
                                 cancellationToken: cancellationToken)
  {
    [weak context] () -> Future<T> in
    guard let context = context
      else { throw AsyncNinjaError.contextDeallocated }

    return try block(context)
  }

  context.addDependent(finite: promiseValue)

  return promiseValue
}

// MARK: - internal helper methods

/// internal use only
private func promise<T>(executor: Executor,
                     after timeout: Double,
                     cancellationToken: CancellationToken?,
                     block: @escaping () throws -> T) -> Promise<T> {
  let promise = Promise<T>()

  cancellationToken?.add(cancellable: promise)

  executor.execute(after: timeout) { [weak promise] in
    if cancellationToken?.isCancelled ?? false {
      promise?.cancel()
    } else {
      let completion = fallible(block: block)
      promise?.complete(with: completion)
    }
  }

  return promise
}

/// **internal use only**
private func flatPromise<T>(executor: Executor,
                         after timeout: Double,
                         cancellationToken: CancellationToken?,
                         block: @escaping () throws -> Future<T>) -> Promise<T> {
  let promise = Promise<T>()

  cancellationToken?.add(cancellable: promise)

  executor.execute(after: timeout) { [weak promise] in
    guard nil != promise else { return }
    if cancellationToken?.isCancelled ?? false {
      promise?.cancel()
    } else {
      do {
        let futureResult = try block()
        promise?.complete(with: futureResult)
      }
      catch {
        promise?.fail(with: error)
      }
    }
  }
  return promise
}
