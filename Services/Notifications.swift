//
//  Notifications.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import Foundation
import UserNotifications
import UIKit

// Singelton set up
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    // Centralized identifiers
    private struct IDs {
        static let category = "SURVEY_CATEGORY"
        static let surveyReminder = "DailySurveyReminder"
        static let actionTake = "ACTION_TAKE_SURVEY"
        static let actionSnooze = "ACTION_SNOOZE_15"
    }
    
    // Call this once on app start (sets delegate + actions)
    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories(on: center)
    }
    
    // Ask for permission (call early, e.g., at first Home launch)
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    cont.resume(returning: granted)
                }
        }
    }
   
    
// MARK: Scheduling (supports one or many surveys)

    // Build a survey URL with uid + defaults, preserving any existing query items.
    private func buildSurveyURL(baseURL: URL, userId: UUID, extras: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items = comps.queryItems ?? []
        
        // Prevent duplicate keys if baseURL already includes them
        let reservedKeys: Set<String> = ["uid", "platform", "app"]
        items.removeAll { reservedKeys.contains($0.name) }
        
        items.append(URLQueryItem(name: "uid", value: userId.uuidString))
        items.append(URLQueryItem(name: "platform", value: "ios"))
        items.append(URLQueryItem(name: "app", value: "inoxity"))
        items.append(contentsOf: extras)
        
        comps.queryItems = items
        return comps.url ?? baseURL
    }

    // Schedule a daily survey with a unique identifier and custom text
    // This handles the "today" case: if the time hasn't passed yet today, schedules for today
    // If it has passed, schedules for tomorrow (via recurring trigger) and also sends one today
    func scheduleDailySurvey(identifier: String,
                             hour: Int,
                             minute: Int,
                             baseURL: URL,
                             userId: UUID,
                             title: String = "Daily Survey Reminder",
                             body: String = "Please take your daily Qualtrics survey!",
                             extras: [URLQueryItem] = []) {
        let center = UNUserNotificationCenter.current()

        // Prevents duplicates when you reschedule
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = IDs.category
        
        // Build userInfo with URL and notification type for streak tracking
        // Tag bedtime/evening notification so we can detect it when tapped
        var userInfo: [String: Any] = ["url": buildSurveyURL(baseURL: baseURL, userId: userId, extras: extras).absoluteString]
        if identifier == "EMA_Evening" {
            userInfo["type"] = "bedtimeReminder"
        }
        content.userInfo = userInfo

        // Calculate the target time for today
        let calendar = Calendar.current
        let now = Date()
        guard let targetTimeToday = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            print("🔔 Failed to create target time")
            return
        }

        // Schedule the recurring notification (for future days)
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let recurringTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let recurringRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: recurringTrigger)

        center.add(recurringRequest) { error in
            if let error = error {
                print("🔔 Schedule error (\(identifier)):", error.localizedDescription)
            } else {
                print("🔔 Scheduled recurring \(identifier) at \(hour):\(String(format: "%02d", minute))")
            }
        }

        // Only schedule a "today" catch-up if time has already passed
        // If time hasn't passed, the recurring trigger will fire today (no duplicate needed)
        if targetTimeToday > now {
            // Time hasn't passed today → recurring will fire today, skip duplicate
            print("🔔 Scheduling only recurring \(identifier) for today/future.")
        } else {
            // If time already passed schedule one quick catch-up, then tomorrow's recurring covers future days
            let todayIdentifier = "\(identifier).today"
            center.removePendingNotificationRequests(withIdentifiers: [todayIdentifier])
            
            let todayContent = content.mutableCopy() as! UNMutableNotificationContent
            let todayTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let todayRequest = UNNotificationRequest(identifier: todayIdentifier, content: todayContent, trigger: todayTrigger)
            center.add(todayRequest) { error in
                if let error = error {
                    print("🔔 Today notification error (\(identifier)):", error.localizedDescription)
                }
            }
            print("🔔 Time has passed today, scheduling catch-up \(identifier) for ~1 minute from now")
        }
    }

    // Backwards-compatible helper: schedules a single daily survey using a default identifier
    func scheduleDailySurvey(hour: Int,
                             minute: Int,
                             baseURL: URL,
                             userId: UUID) {
        scheduleDailySurvey(identifier: IDs.surveyReminder,
                            hour: hour,
                            minute: minute,
                            baseURL: baseURL,
                            userId: userId)
    }
    
    // Helper to reschedule evening notification based on bedtimeMinutes
    // Calculates notification time as 60 minutes before bedtime
    func rescheduleEveningNotification(bedtimeMinutes: Int, surveyURL: URL, userId: UUID) {
        let bedtimeHour = max(0, min(23, bedtimeMinutes / 60))
        let bedtimeMinute = max(0, min(59, bedtimeMinutes % 60))
        let calendar = Calendar.current
        var beforeDate = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: Date()) ?? Date()
        beforeDate = calendar.date(byAdding: .minute, value: -60, to: beforeDate) ?? beforeDate
        let beforeHour = calendar.component(.hour, from: beforeDate)
        let beforeMinute = calendar.component(.minute, from: beforeDate)
        
        scheduleDailySurvey(
            identifier: "EMA_Evening",
            hour: beforeHour,
            minute: beforeMinute,
            baseURL: surveyURL,
            userId: userId,
            title: "Evening Check-in",
            body: "How was your day?"
        )
    }

// MARK: Categories & Actions
    
    private func registerCategories(on center: UNUserNotificationCenter) {
        let take = UNNotificationAction(
            identifier: IDs.actionTake,
            title: "Take Survey",
            options: [.foreground] // opens the app then the notification
        )
        let snooze = UNNotificationAction(
            identifier: IDs.actionSnooze,
            title: "Snooze 15 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: IDs.category,
            actions: [take, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
    
    
// MARK: - UNUserNotificationCenterDelegate
    
// Show banner/sound even if app is foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle taps & actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let urlString = info["url"] as? String
        
        // Check if this is the bedtime/evening notification tap for streak tracking
        // Detect using either the identifier or userInfo["type"]
        let request = response.notification.request
        let isBedtimeNotification = request.identifier == "EMA_Evening" ||
                                     request.identifier.hasPrefix("EMA_Evening") ||
                                     (info["type"] as? String) == "bedtimeReminder"
        
        if isBedtimeNotification {
            // Mark today's streak as completed when user taps the evening notification
            StreakManager.shared.markTodayCompletedFromNotification()
            print("🔔 Bedtime notification tapped - streak updated")
        }

        switch response.actionIdentifier {
        case IDs.actionSnooze:
            // Re-fire once after 15 minutes
            let content = response.notification.request.content.mutableCopy() as! UNMutableNotificationContent
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
            let id = "\(request.identifier).snooze.\(UUID().uuidString)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req)

        case IDs.actionTake, UNNotificationDefaultActionIdentifier:
            if let urlString, let url = URL(string: urlString) {
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            } else {
                print("🔔 No URL found in userInfo")
            }

        default:
            break
        }

        completionHandler()
    }
}


