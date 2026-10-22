import Foundation

/// An error the shooter can read. Every error that can reach a screen conforms, so views never show
/// `localizedDescription` of a system error and never show nothing.
public protocol UserFacingError: Error {
    /// One sentence, plain words, what happened.
    var message: String { get }
    /// One sentence, what to do; nil when there is nothing to do.
    var recovery: String? { get }
}

public extension UserFacingError {
    var recovery: String? { nil }
    /// Message and recovery joined for a single label.
    var text: String { recovery.map { message + " " + $0 } ?? message }
}

/// A round that cannot be written as document JSON (a time, level or weather value that is not a finite number).
public enum RoundDocumentError: Error, Equatable, UserFacingError {
    case notEncodable
    public var message: String { "This round has a value that cannot be saved." }
    public var recovery: String? { "Check the times and weather of the round, then save again." }
}

/// Wraps any error for display. Unknown errors get a generic message; the detail goes to the log, not the screen.
public struct DisplayError: UserFacingError, Equatable {
    public let message: String
    public let recovery: String?
    public init(_ message: String, recovery: String? = nil) { self.message = message; self.recovery = recovery }
    public init(any error: Error, fallback: String = "Something went wrong.") {
        if let e = error as? UserFacingError { self.init(e.message, recovery: e.recovery) } else { self.init(fallback) }
    }
}
