import Foundation
import TrapCore

/// Where rounds live. The app talks to this protocol only; the implementation is SwiftData on the device
/// and a dictionary in tests and previews.
@MainActor
public protocol RoundRepository: AnyObject {
    /// Newest first.
    func fetchAll() throws -> [Round]
    func fetch(id: String) throws -> Round?
    /// Insert or replace.
    func save(_ round: Round) throws
    func delete(id: String) throws
    /// For session id uniqueness.
    func sessionIdentifiers() throws -> [(id: String, sessionId: String)]
}

public extension RoundRepository {
    /// A new round whose session id is unique in this repository.
    func makeRound(now: Date = Date(), shooter: String = "") throws -> Round {
        var r = Round.new(now: now)
        r.shooter = shooter
        r.sessionId = SessionID.make(for: r, existing: try sessionIdentifiers(), now: now)
        return r
    }
}

/// Rounds in a dictionary. Tests, previews, and the import preview.
@MainActor
public final class InMemoryRoundRepository: RoundRepository {
    private var rounds: [String: Round] = [:]
    public init(_ initial: [Round] = []) { for r in initial { rounds[r.id] = r } }
    public func fetchAll() throws -> [Round] { rounds.values.sorted { $0.createdAt > $1.createdAt } }
    public func fetch(id: String) throws -> Round? { rounds[id] }
    public func save(_ round: Round) throws { rounds[round.id] = round }
    public func delete(id: String) throws { rounds[id] = nil }
    public func sessionIdentifiers() throws -> [(id: String, sessionId: String)] { rounds.values.map { (id: $0.id, sessionId: $0.sessionId) } }
    public var count: Int { rounds.count }
}
