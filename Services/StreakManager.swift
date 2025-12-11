//
//  StreakManager.swift
//  Inoxity
//
//  Created for streak tracking from notification taps
//

import Foundation

/// Manages streak completion tracking, particularly from notification taps.
/// Uses the same storage as HomeScreen's survey completion tracking.
final class StreakManager {
    static let shared = StreakManager()
    
    private init() {}
    
    /// UserDefaults key for storing completed streak days (same as survey completion tracking)
    private let streakDaysKey = "completedSurveyDates"
    
    /// Get today's date as a normalized calendar day key (yyyy-MM-dd)
    private func todayKey() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let normalized = calendar.date(from: components) else {
            // Fallback: use formatter directly
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: now)
        }
        
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: normalized)
    }
    
    /// Get the set of completed streak days from UserDefaults
    private var streakDays: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: streakDaysKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: streakDaysKey)
            UserDefaults.standard.synchronize() // Force immediate write
        }
    }
    
    /// Mark today's streak as completed when the user taps the evening notification.
    /// This is idempotent: calling multiple times on the same day only updates once.
    /// After successfully adding today's date, syncs to Supabase.
    func markTodayCompletedFromNotification() {
        let today = todayKey()
        var days = streakDays
        
        // Check if today is already counted (no double counting)
        guard !days.contains(today) else {
            print("📊 Streak already marked for today (\(today)); skipping")
            return
        }
        
        // Add today and persist
        days.insert(today)
        streakDays = days
        
        print("✅ Marked streak completed for \(today) from notification tap")
        print("📊 Current streak days: \(Array(days).sorted())")
        
        // Sync to Supabase after successfully adding today
        pushStreakToSupabase()
    }
    
    /// Push the updated streak data to Supabase.
    /// Uses the existing Supabase client patterns for async operations.
    private func pushStreakToSupabase() {
        let days = streakDays
        let sortedDays = Array(days).sorted()
        
        Task {
            do {
                try await SupabaseClient.shared.updateStreak(streakDays: sortedDays)
                print("✅ Streak synced to Supabase: \(sortedDays.count) days")
            } catch {
                print("⚠️ Failed to sync streak to Supabase: \(error.localizedDescription)")
                // Don't throw - this is best-effort sync
            }
        }
    }
}
