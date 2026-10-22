import Foundation
import SwiftData
import TrapCore

/// What a list row needs. Fetched without the document payload (`propertiesToFetch`), so a thousand rows cost
/// a thousand small tuples, not a thousand JSON decodes.
public struct RoundSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let createdAt: String
    public let date: String
    public let scheme: Int
    public let type: String
    public let sessionId: String
    public let place: String
    public let score: Int
    public let recorded: Int
    public var isFull: Bool { recorded == Round.targetCount }
    public init(id: String, createdAt: String, date: String, scheme: Int, type: String, sessionId: String, place: String, score: Int, recorded: Int) {
        self.id = id; self.createdAt = createdAt; self.date = date; self.scheme = scheme; self.type = type
        self.sessionId = sessionId; self.place = place; self.score = score; self.recorded = recorded
    }
    public init(_ r: Round) {
        self.init(id: r.id, createdAt: r.createdAt, date: r.date, scheme: r.scheme, type: r.type, sessionId: r.sessionId, place: r.place, score: r.score, recorded: r.recorded)
    }
}

/// A WHERE clause for rounds. All parts optional and ANDed.
public struct RoundFilter: Equatable, Sendable {
    public var scheme: Int?
    public var type: String?
    /// Inclusive, "yyyy-MM-dd".
    public var dateFrom: String?
    public var dateTo: String?
    public var fullOnly = false
    /// Case‑insensitive search in range name and session id.
    public var text: String?
    public init(scheme: Int? = nil, type: String? = nil, dateFrom: String? = nil, dateTo: String? = nil, fullOnly: Bool = false, text: String? = nil) {
        self.scheme = scheme; self.type = type; self.dateFrom = dateFrom; self.dateTo = dateTo; self.fullOnly = fullOnly
        self.text = text.flatMap { t in let s = t.trimmingCharacters(in: .whitespaces); return s.isEmpty ? nil : s }
    }
    public static let all = RoundFilter()

    func matches(_ s: RoundSummary) -> Bool {
        if let v = scheme, s.scheme != v { return false }
        if let v = type, s.type != v { return false }
        if let v = dateFrom, s.date < v { return false }
        if let v = dateTo, s.date > v { return false }
        if fullOnly, !s.isFull { return false }
        if let t = text, !(s.place.localizedStandardContains(t) || s.sessionId.localizedStandardContains(t)) { return false }
        return true
    }
}

public extension RoundRepository {
    /// Defaults: everything through `fetchAll`. SwiftData overrides these with column fetches and one transaction.
    func summaries(filter: RoundFilter, limit: Int?, offset: Int) throws -> [RoundSummary] {
        let all = try fetchAll().map(RoundSummary.init).filter(filter.matches)
        let sliced = all.dropFirst(offset)
        return limit.map { Array(sliced.prefix($0)) } ?? Array(sliced)
    }
    func countRounds(filter: RoundFilter) throws -> Int { try summaries(filter: filter, limit: nil, offset: 0).count }
    func saveMany(_ rounds: [Round]) throws { for r in rounds { try save(r) } }

    // Conveniences with defaults (protocol requirements cannot carry default arguments).
    func fetchSummaries(_ filter: RoundFilter = .all, limit: Int? = nil, offset: Int = 0) throws -> [RoundSummary] {
        try summaries(filter: filter, limit: limit, offset: offset)
    }
    func count(_ filter: RoundFilter = .all) throws -> Int { try countRounds(filter: filter) }
}

public extension SwiftDataRoundRepository {
    private func descriptor(_ f: RoundFilter) -> FetchDescriptor<RoundRecord> {
        // Optionals are captured as (flag, value) pairs: #Predicate cannot unwrap optionals itself.
        let useScheme = f.scheme != nil, scheme = f.scheme ?? 0
        let useType = f.type != nil, type = f.type ?? ""
        let useFrom = f.dateFrom != nil, from = f.dateFrom ?? ""
        let useTo = f.dateTo != nil, to = f.dateTo ?? ""
        let fullOnly = f.fullOnly, full = Round.targetCount
        let useText = f.text != nil, text = f.text ?? ""
        var d = FetchDescriptor<RoundRecord>(
            predicate: #Predicate { r in
                (!useScheme || r.scheme == scheme) && (!useType || r.type == type) &&
                (!useFrom || r.date >= from) && (!useTo || r.date <= to) && (!fullOnly || r.recorded == full) &&
                (!useText || r.place.localizedStandardContains(text) || r.sessionId.localizedStandardContains(text))
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.propertiesToFetch = [\.id, \.createdAt, \.date, \.scheme, \.type, \.sessionId, \.place, \.score, \.recorded]
        return d
    }

    func summaries(filter: RoundFilter, limit: Int?, offset: Int) throws -> [RoundSummary] {
        var d = descriptor(filter)
        d.fetchOffset = offset
        if let limit { d.fetchLimit = limit }
        return try context.fetch(d).map {
            RoundSummary(id: $0.id, createdAt: $0.createdAt, date: $0.date, scheme: $0.scheme, type: $0.type, sessionId: $0.sessionId, place: $0.place, score: $0.score, recorded: $0.recorded)
        }
    }

    func countRounds(filter: RoundFilter) throws -> Int { try context.fetchCount(descriptor(filter)) }

    /// One transaction: autosave off, every row applied, one save; on any error the context is rolled back.
    func saveMany(_ rounds: [Round]) throws {
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            for r in rounds {
                if let existing = try record(id: r.id) { try existing.update(from: r) } else { context.insert(try RoundRecord.make(round: r)) }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
