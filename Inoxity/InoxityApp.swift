//
//  InoxityApp.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import UserNotifications

@main
struct KeeAppApp: App {
    private let surveyMorningURL = URL(string: "https://ucdavis.co1.qualtrics.com/jfe/form/SV_3lyi79274NwvyqW")!
    private let surveyEveningURL = URL(string: "https://ucdavis.co1.qualtrics.com/jfe/form/SV_3lyi79274NwvyqW")!
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60
    @StateObject private var supabaseService = SupabaseClient.shared

    init() {
        // Set the delegate early so taps work on cold start
        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
                .task {
                    let granted = await NotificationService.shared.requestAuthorization()
                    guard granted else { return }

                    // one-time guard
                    if !UserDefaults.standard.bool(forKey: "didScheduleNotifications") {
                        let uid = IdentityService.shared.userId

                        NotificationService.shared.scheduleDailySurvey(
                            identifier: "EMA_Morning",
                            hour: 9, minute: 15,
                            baseURL: surveyMorningURL,
                            userId: uid,
                            title: "Morning Check-in",
                            body: "Quick 2-minute survey."
                        )

                        NotificationService.shared.rescheduleEveningNotification(
                            bedtimeMinutes: bedtimeMinutes,
                            surveyURL: surveyEveningURL,
                            userId: uid
                        )

                        UserDefaults.standard.set(true, forKey: "didScheduleNotifications")
                    }
                }
                .onChange(of: bedtimeMinutes) { _, newValue in
                    // Reschedule evening notification when bedtime changes
                    Task {
                        let granted = await NotificationService.shared.requestAuthorization()
                        guard granted else { return }
                        let uid = IdentityService.shared.userId
                        NotificationService.shared.rescheduleEveningNotification(
                            bedtimeMinutes: newValue,
                            surveyURL: surveyEveningURL,
                            userId: uid
                        )
                    }
                }
        }
    }
}
