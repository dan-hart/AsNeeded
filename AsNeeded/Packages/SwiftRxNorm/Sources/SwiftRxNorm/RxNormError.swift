import Foundation

/// Errors that can be thrown by `RxNormClient`.
public enum RxNormError: Error, LocalizedError {
    case invalidRequest
    case invalidResponse
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Invalid RxNorm API request."
        case .invalidResponse: return "Unexpected response from RxNorm API."
        case .decodingFailed: return "Failed to decode RxNorm API response."
        }
    }
}
