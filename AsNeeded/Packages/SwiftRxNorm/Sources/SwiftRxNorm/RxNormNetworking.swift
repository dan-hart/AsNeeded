import Foundation

/// Protocol for dependency-injected HTTP networking for testability.
public protocol RxNormNetworking: Sendable {
    /// Performs a network data task with the given URLRequest.
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the returned Data and URLResponse.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: RxNormNetworking {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await self.data(for: request, delegate: nil)
    }
}
