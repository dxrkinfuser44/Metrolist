import Foundation

/// Extension to allow `Result` to be initialized with an async throwing closure.
/// Swift's standard `Result.init(catching:)` only accepts synchronous closures.
extension Result where Failure == Error {
    /// Initialize a Result from an async throwing closure.
    init(asyncCatching body: @Sendable () async throws -> Success) async {
        do {
            let value = try await body()
            self = .success(value)
        } catch {
            self = .failure(error)
        }
    }
}
