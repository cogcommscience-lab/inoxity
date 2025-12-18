//
//  StreakManager.swift
//  Inoxity
//
//  Created for streak tracking from notification taps
//

import Foundation

final class StreakManager {
    static let shared = StreakManager()
    private init() {}

    // ✅ Keep survey completion storage separate from streak completion storage
    private let surveyDaysKey  = "completedSurveyDates"
    private let streakDaysKey  = "completedStreakDates"

    // These must match your HomeView @AppStorage keys
    private let didSleepKey    = "didSleepToday"
    private let didUploadKey   = "didUploadToday"

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dayKey(_ date: Date) -> String {
        // Normalize to calendar day
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let normalized = cal.date(from: comps) ?? date
        return Self.dayKeyFormatter.string(from: normalized)
    }

    private func todayKey() -> String { dayKey(Date()) }

    // MARK: Storage

    private var streakDays: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: streakDaysKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: streakDaysKey) }
    }

    private func didSurveyToday(_ today: String) -> Bool {
        let arr = UserDefaults.standard.stringArray(forKey: surveyDaysKey) ?? []
        return Set(arr).contains(today)
    }

    private func didSleepToday() -> Bool {
        UserDefaults.standard.bool(forKey: didSleepKey)
    }

    private func didUploadToday() -> Bool {
        UserDefaults.standard.bool(forKey: didUploadKey)
    }

    private func allThreeCompletedToday() -> Bool {
        let today = todayKey()
        return didSleepToday() && didUploadToday() && didSurveyToday(today)
    }

    // MARK: Public API

    /// Call this when the user taps the evening notification.
    /// ✅ Will only write/upload streak if: Sleep + Survey + ST are ALL completed today.
    func markTodayCompletedFromNotification() {
        let today = todayKey()

        guard allThreeCompletedToday() else {
            print("⚠️ Streak NOT recorded: missing one or more tasks for \(today)")
            print("   Sleep=\(didSleepToday())  Survey=\(didSurveyToday(today))  ST=\(didUploadToday())")
            return
        }

        var days = streakDays

        // idempotent
        guard !days.contains(today) else {
            print("📊 Streak already recorded for \(today); skipping")
            return
        }

        days.insert(today)
        streakDays = days

        print("✅ Streak recorded for \(today) (all 3 tasks complete)")
        pushStreakToSupabase()
    }

    // MARK: Supabase sync

    private func pushStreakToSupabase() {
        let sortedDays = Array(streakDays).sorted()
        Task {
            do {
                try await SupabaseService.shared.updateStreak(streakDays: sortedDays)
                print("✅ Streak synced to Supabase: \(sortedDays.count) days")
            } catch {
                print("⚠️ Failed to sync streak to Supabase: \(error.localizedDescription)")
            }
        }
    }
}

