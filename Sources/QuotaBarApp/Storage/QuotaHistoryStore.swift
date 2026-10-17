import Foundation
import SQLite3

enum QuotaHistoryStoreError: Error, Equatable {
    case openFailed(String)
    case executeFailed(String)
}

/// Hourly remaining-quota / balance series in a local SQLite file.
/// One row per (`service`, `metricKey`, local hour). Repeated samples in the
/// same hour accumulate `consumed` (remaining dropped) and `restored` (reset
/// or top-up). Day / week / month views group these hour rows; gaps stay gaps.
final class QuotaHistoryStore: @unchecked Sendable {
    private let databaseURL: URL
    private let calendar: Calendar
    private let queue = DispatchQueue(label: "com.local.quotabar.history")
    private var db: OpaquePointer?

    init(databaseURL: URL = AppPaths.quotaHistoryDatabase, calendar: Calendar = .current) {
        self.databaseURL = databaseURL
        self.calendar = calendar
    }

    deinit {
        if let db {
            sqlite3_close_v2(db)
        }
    }

    func record(_ samples: [QuotaHistorySample]) throws {
        guard !samples.isEmpty else { return }
        try queue.sync {
            try recordLocked(samples)
        }
    }

    func record(_ sample: QuotaHistorySample) throws {
        try record([sample])
    }

    func hourRecords(
        service: ServiceKind? = nil,
        metricKey: String? = nil,
        canonicalOnly: Bool = false,
        from: Date,
        to: Date
    ) throws -> [QuotaHourRecord] {
        try queue.sync {
            try hourRecordsLocked(
                service: service,
                metricKey: metricKey,
                canonicalOnly: canonicalOnly,
                from: from,
                to: to
            )
        }
    }

    func aggregatedRecords(
        service: ServiceKind,
        metricKey: String,
        from: Date,
        to: Date,
        bucket: QuotaHistoryBucket
    ) throws -> [QuotaHistoryAggregate] {
        let hours = try hourRecords(service: service, metricKey: metricKey, from: from, to: to)
        var groups: [(start: Date, records: [QuotaHourRecord])] = []
        var index: [Date: Int] = [:]
        for record in hours {
            let start = QuotaHistoryClock.bucketStart(bucket, of: record.hourStart, calendar: calendar)
            if let existing = index[start] {
                groups[existing].records.append(record)
            } else {
                index[start] = groups.count
                groups.append((start, [record]))
            }
        }
        return groups.map { start, records in
            QuotaHistoryAggregate(
                periodStart: start,
                opening: records[0].opening,
                closing: records[records.count - 1].closing,
                consumed: records.reduce(0) { $0 + $1.consumed },
                restored: records.reduce(0) { $0 + $1.restored },
                sampleCount: records.reduce(0) { $0 + $1.sampleCount }
            )
        }
    }

    func close() {
        queue.sync {
            if let db {
                sqlite3_close_v2(db)
                self.db = nil
            }
        }
    }

    private func recordLocked(_ samples: [QuotaHistorySample]) throws {
        try openIfNeeded()
        try execute("BEGIN IMMEDIATE")
        do {
            for sample in samples {
                try upsertLocked(sample)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func upsertLocked(_ sample: QuotaHistorySample) throws {
        let hourStart = QuotaHistoryClock.hourStart(of: sample.capturedAt, calendar: calendar)
        let hourStartSeconds = unixSeconds(hourStart)
        if var existing = try fetchLocked(
            service: sample.service,
            metricKey: sample.metricKey,
            hourStart: hourStartSeconds
        ) {
            applyDelta(&existing, remaining: sample.remaining, unit: sample.unit)
            existing.closing = sample.remaining
            existing.unit = sample.unit
            existing.sampleCount += 1
            existing.lastSampleAt = sample.capturedAt
            existing.isCanonical = sample.isCanonical
            try updateLocked(existing)
        } else {
            var record = QuotaHourRecord(
                service: sample.service,
                metricKey: sample.metricKey,
                hourStart: hourStart,
                unit: sample.unit,
                opening: sample.remaining,
                closing: sample.remaining,
                consumed: 0,
                restored: 0,
                sampleCount: 1,
                lastSampleAt: sample.capturedAt,
                isCanonical: sample.isCanonical
            )
            if let previous = try fetchPreviousLocked(
                service: sample.service,
                metricKey: sample.metricKey,
                beforeHourStart: hourStartSeconds
            ), previous.unit == sample.unit {
                record.opening = previous.closing
                record.closing = previous.closing
                applyDelta(&record, remaining: sample.remaining, unit: sample.unit)
                record.closing = sample.remaining
            }
            try insertLocked(record)
        }
    }

    private func fetchLocked(
        service: ServiceKind,
        metricKey: String,
        hourStart: Int64
    ) throws -> QuotaHourRecord? {
        let sql = """
            SELECT service_kind, metric_key, hour_start, unit, opening, closing,
                   consumed, restored, sample_count, last_sample_at, is_canonical
            FROM quota_hour_stats
            WHERE service_kind = ? AND metric_key = ? AND hour_start = ?
            LIMIT 1
            """
        var found: QuotaHourRecord?
        try withStatement(sql) { statement in
            bind(statement, 1, service.rawValue)
            bind(statement, 2, metricKey)
            sqlite3_bind_int64(statement, 3, hourStart)
            if sqlite3_step(statement) == SQLITE_ROW {
                found = row(statement)
            }
        }
        return found
    }

    private func fetchPreviousLocked(
        service: ServiceKind,
        metricKey: String,
        beforeHourStart: Int64
    ) throws -> QuotaHourRecord? {
        let sql = """
            SELECT service_kind, metric_key, hour_start, unit, opening, closing,
                   consumed, restored, sample_count, last_sample_at, is_canonical
            FROM quota_hour_stats
            WHERE service_kind = ? AND metric_key = ? AND hour_start < ?
            ORDER BY hour_start DESC
            LIMIT 1
            """
        var found: QuotaHourRecord?
        try withStatement(sql) { statement in
            bind(statement, 1, service.rawValue)
            bind(statement, 2, metricKey)
            sqlite3_bind_int64(statement, 3, beforeHourStart)
            if sqlite3_step(statement) == SQLITE_ROW {
                found = row(statement)
            }
        }
        return found
    }

    private func applyDelta(
        _ record: inout QuotaHourRecord,
        remaining: Double,
        unit: QuotaHistoryUnit
    ) {
        guard record.unit == unit else { return }
        let delta = record.closing - remaining
        let threshold = epsilon(for: unit)
        if delta > threshold {
            record.consumed += delta
        } else if delta < -threshold {
            record.restored += -delta
        }
    }

    private func insertLocked(_ record: QuotaHourRecord) throws {
        let sql = """
            INSERT INTO quota_hour_stats (
                service_kind, metric_key, hour_start, unit, opening, closing,
                consumed, restored, sample_count, last_sample_at, is_canonical
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withStatement(sql) { statement in
            bindRecord(statement, record)
            try stepDone(statement)
        }
    }

    private func updateLocked(_ record: QuotaHourRecord) throws {
        let sql = """
            UPDATE quota_hour_stats
            SET unit = ?, opening = ?, closing = ?, consumed = ?, restored = ?,
                sample_count = ?, last_sample_at = ?, is_canonical = ?
            WHERE service_kind = ? AND metric_key = ? AND hour_start = ?
            """
        try withStatement(sql) { statement in
            bind(statement, 1, record.unit.rawValue)
            sqlite3_bind_double(statement, 2, record.opening)
            sqlite3_bind_double(statement, 3, record.closing)
            sqlite3_bind_double(statement, 4, record.consumed)
            sqlite3_bind_double(statement, 5, record.restored)
            sqlite3_bind_int64(statement, 6, Int64(record.sampleCount))
            sqlite3_bind_int64(statement, 7, unixSeconds(record.lastSampleAt))
            sqlite3_bind_int(statement, 8, record.isCanonical ? 1 : 0)
            bind(statement, 9, record.service.rawValue)
            bind(statement, 10, record.metricKey)
            sqlite3_bind_int64(statement, 11, unixSeconds(record.hourStart))
            try stepDone(statement)
        }
    }

    private func hourRecordsLocked(
        service: ServiceKind?,
        metricKey: String?,
        canonicalOnly: Bool,
        from: Date,
        to: Date
    ) throws -> [QuotaHourRecord] {
        try openIfNeeded()
        var sql = """
            SELECT service_kind, metric_key, hour_start, unit, opening, closing,
                   consumed, restored, sample_count, last_sample_at, is_canonical
            FROM quota_hour_stats
            WHERE hour_start >= ? AND hour_start < ?
            """
        if service != nil {
            sql += " AND service_kind = ?"
        }
        if metricKey != nil {
            sql += " AND metric_key = ?"
        }
        if canonicalOnly {
            sql += " AND is_canonical = 1"
        }
        sql += " ORDER BY hour_start ASC, service_kind ASC, metric_key ASC"

        var records: [QuotaHourRecord] = []
        try withStatement(sql) { statement in
            sqlite3_bind_int64(
                statement,
                1,
                unixSeconds(QuotaHistoryClock.hourStart(of: from, calendar: calendar))
            )
            sqlite3_bind_int64(statement, 2, unixSeconds(to))
            var index: Int32 = 3
            if let service {
                bind(statement, index, service.rawValue)
                index += 1
            }
            if let metricKey {
                bind(statement, index, metricKey)
            }
            while sqlite3_step(statement) == SQLITE_ROW {
                if let record = row(statement) {
                    records.append(record)
                }
            }
        }
        return records
    }

    private func row(_ statement: OpaquePointer) -> QuotaHourRecord? {
        guard let service = ServiceKind(rawValue: columnText(statement, 0)),
              let unit = QuotaHistoryUnit(rawValue: columnText(statement, 3)) else {
            return nil
        }
        return QuotaHourRecord(
            service: service,
            metricKey: columnText(statement, 1),
            hourStart: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2))),
            unit: unit,
            opening: sqlite3_column_double(statement, 4),
            closing: sqlite3_column_double(statement, 5),
            consumed: sqlite3_column_double(statement, 6),
            restored: sqlite3_column_double(statement, 7),
            sampleCount: Int(sqlite3_column_int64(statement, 8)),
            lastSampleAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 9))),
            isCanonical: sqlite3_column_int(statement, 10) != 0
        )
    }

    private func bindRecord(_ statement: OpaquePointer, _ record: QuotaHourRecord) {
        bind(statement, 1, record.service.rawValue)
        bind(statement, 2, record.metricKey)
        sqlite3_bind_int64(statement, 3, unixSeconds(record.hourStart))
        bind(statement, 4, record.unit.rawValue)
        sqlite3_bind_double(statement, 5, record.opening)
        sqlite3_bind_double(statement, 6, record.closing)
        sqlite3_bind_double(statement, 7, record.consumed)
        sqlite3_bind_double(statement, 8, record.restored)
        sqlite3_bind_int64(statement, 9, Int64(record.sampleCount))
        sqlite3_bind_int64(statement, 10, unixSeconds(record.lastSampleAt))
        sqlite3_bind_int(statement, 11, record.isCanonical ? 1 : 0)
    }

    private func openIfNeeded() throws {
        if db != nil { return }
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = databaseURL.path.withCString { path in
            sqlite3_open_v2(path, &db, flags, nil)
        }
        guard status == SQLITE_OK, db != nil else {
            let message = db.map(Self.errorMessage) ?? "unable to open quota history database"
            if let db {
                sqlite3_close_v2(db)
            }
            db = nil
            throw QuotaHistoryStoreError.openFailed(message)
        }
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
        try execute("PRAGMA busy_timeout=5000")
        try migrate()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: databaseURL.path
        )
        for suffix in ["-wal", "-shm"] {
            let sidecar = databaseURL.path + suffix
            if FileManager.default.fileExists(atPath: sidecar) {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: sidecar
                )
            }
        }
    }

    private func migrate() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS quota_hour_stats (
                service_kind TEXT NOT NULL,
                metric_key TEXT NOT NULL,
                hour_start INTEGER NOT NULL,
                unit TEXT NOT NULL,
                opening REAL NOT NULL,
                closing REAL NOT NULL,
                consumed REAL NOT NULL DEFAULT 0,
                restored REAL NOT NULL DEFAULT 0,
                sample_count INTEGER NOT NULL DEFAULT 1,
                last_sample_at INTEGER NOT NULL,
                is_canonical INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (service_kind, metric_key, hour_start)
            )
            """)
        try execute(
            "CREATE INDEX IF NOT EXISTS idx_quota_hour_stats_range ON quota_hour_stats (service_kind, hour_start)"
        )
        try execute("PRAGMA user_version = 1")
    }

    private func execute(_ sql: String) throws {
        guard let db else {
            throw QuotaHistoryStoreError.executeFailed("database closed")
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if let errorMessage {
            let message = String(cString: errorMessage)
            sqlite3_free(errorMessage)
            if status != SQLITE_OK {
                throw QuotaHistoryStoreError.executeFailed(message)
            }
        } else if status != SQLITE_OK {
            throw QuotaHistoryStoreError.executeFailed(Self.errorMessage(db))
        }
    }

    private func withStatement(_ sql: String, body: (OpaquePointer) throws -> Void) throws {
        guard let db else {
            throw QuotaHistoryStoreError.executeFailed("database closed")
        }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            throw QuotaHistoryStoreError.executeFailed(Self.errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else {
            throw QuotaHistoryStoreError.executeFailed(db.map(Self.errorMessage) ?? "statement failed")
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ text: String) {
        sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private func unixSeconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }

    private func epsilon(for unit: QuotaHistoryUnit) -> Double {
        switch unit {
        case .percent:
            return 0.05
        case .currency:
            return 0.005
        }
    }

    private static func errorMessage(_ db: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(db))
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
