//
//  SleepSyncer.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import Foundation
import HealthKit
import UIKit   // for UIApplication background tasks


// MARK: - Public sync service
final class SleepSyncer {
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // One-time history pull (e.g., last 30–90 days)
    func backfill(userId: UUID, days: Int = 30) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples = try await fetchSamples(predicate: predicate)
        try await upload(samples: samples, userId: userId)
    }

    // Fast incremental sync using an anchor bookmark
    func syncIncremental(userId: UUID) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let oldAnchor = AnchorStore.load()
        let (samples, newAnchor) = try await fetchWithAnchor(oldAnchor)
        if !samples.isEmpty {
            try await upload(samples: samples, userId: userId)
        }
        AnchorStore.save(newAnchor)
    }

    // Enable passive/background delivery (call after auth succeeds)
    func enableBackgroundDelivery(userId: UUID) {
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            if !success { print("BG delivery failed:", error?.localizedDescription ?? "") }
        }

        let observer = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completion, _ in
            // ✅ Tell HealthKit we're done ASAP so the system can throttle/queue correctly.
            completion()

            guard let self else { return }

            // ✅ Do the real work in an app background task, and ALWAYS end it.
            DispatchQueue.main.async {
                var bgID = UIBackgroundTaskIdentifier.invalid
                bgID = UIApplication.shared.beginBackgroundTask(withName: "HK Sleep Incremental Sync") {
                    // expiration handler
                    UIApplication.shared.endBackgroundTask(bgID)
                    bgID = .invalid
                }

                Task {
                    defer {
                        if bgID != .invalid {
                            UIApplication.shared.endBackgroundTask(bgID)
                            bgID = .invalid
                        }
                    }
                    do {
                        try await self.syncIncremental(userId: userId)
                    } catch {
                        print("BG sync error:", error.localizedDescription)
                    }
                }
            }
        }

        healthStore.execute(observer)
    }

    // MARK: Priming the anchor
    // Bookmark the current moment so incremental sync only fetches NEW data going forward.
    func primeAnchorToNow() async throws {
        try await primeAnchor(at: Date())
    }

    // Bookmark any date you want (e.g., the end of a backfill window)
    func primeAnchor(at date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictStartDate)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            // limit: 0 returns no samples but provides a newAnchor we can save
            let q = HKAnchoredObjectQuery(type: self.sleepType,
                                          predicate: predicate,
                                          anchor: nil,
                                          limit: 0) { _, _, _, newAnchor, error in
                if let e = error { cont.resume(throwing: e); return }
                if let a = newAnchor { AnchorStore.save(a) }
                cont.resume(returning: ())
            }
            self.healthStore.execute(q)
        }
    }
}

// MARK: - HealthKit fetching
private extension SleepSyncer {
    func fetchSamples(predicate: NSPredicate?) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKCategorySample], Error>) in
            let q = HKSampleQuery(sampleType: sleepType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, result, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: (result as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(q)
        }
    }

    func fetchWithAnchor(_ anchor: HKQueryAnchor?) async throws -> ([HKCategorySample], HKQueryAnchor) {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<([HKCategorySample], HKQueryAnchor), Error>) in
            let q = HKAnchoredObjectQuery(type: sleepType,
                                          predicate: nil,
                                          anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { _, added, _, newAnchor, error in
                if let error = error { cont.resume(throwing: error); return }
                let samples = (added as? [HKCategorySample]) ?? []
                cont.resume(returning: (samples, newAnchor!))
            }
            healthStore.execute(q)
        }
    }

    func upload(samples: [HKCategorySample], userId: UUID) async throws {
        guard !samples.isEmpty else { return }

        let rows: [SleepRow] = samples.map { s in
            SleepRow(
                user_id: userId,
                hk_uuid: s.uuid,
                start_time: iso.string(from: s.startDate),
                end_time: iso.string(from: s.endDate),
                state: mapSleepValue(s.value),
                source_bundle_id: s.sourceRevision.source.bundleIdentifier
            )
        }

        do {
            try await SupabaseClient.shared.upsertSleepRows(rows)
            print("Uploaded \(rows.count) sleep rows")
        } catch {
            print("⚠️ Supabase upload failed:", error.localizedDescription)
            throw error
        }
    }

    func mapSleepValue(_ raw: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: raw) {
        case .inBed: return "inBed"
        case .awake: return "awake"
        case .asleepUnspecified: return "asleep"
        case .asleepCore: return "asleepCore"
        case .asleepDeep: return "asleepDeep"
        case .asleepREM: return "asleepREM"
        default: return "asleep"
        }
    }
}

// MARK: - Anchor persistence (local)
enum AnchorStore {
    private static let key = "hk_sleep_anchor_base64"

    static func save(_ anchor: HKQueryAnchor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data.base64EncodedString(), forKey: key)
        } catch { print("Anchor save error:", error.localizedDescription) }
    }

    static func load() -> HKQueryAnchor? {
        guard let base64 = UserDefaults.standard.string(forKey: key),
              let data = Data(base64Encoded: base64)
        else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}

// MARK: - Row shape that matches your DB table
struct SleepRow: Encodable {
    let user_id: UUID
    let hk_uuid: UUID
    let start_time: String  // ISO8601 UTC
    let end_time: String    // ISO8601 UTC
    let state: String
    let source_bundle_id: String?
}
