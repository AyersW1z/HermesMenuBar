import Foundation

enum SessionTransportState: String, Equatable {
    case disconnected
    case connecting
    case ready
    case error
}

struct SessionRuntimeState: Equatable {
    var transportState: SessionTransportState = .disconnected
    var isRequestActive = false
    var lastError: String?
    var lastUpdatedAt: Date?
}
