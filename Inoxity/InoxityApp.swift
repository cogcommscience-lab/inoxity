//
//  InoxityApp.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import SwiftUI // required for the SwiftUI app lifecycle
import UserNotifications // required for notification functions

// App entry point
@main // tells the app that this is the starting point
struct InoxityApp: App { // naming the app structure
    
    // Pulling qualtrics links from Config.plist
    private var configPlist: NSDictionary {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            fatalError("Config.plist missing or unreadable. Make sure Config.plist exists and is included in Target Membership.")
        }
        return plist
    }
    
    // Morning Qualtrics EMA URL pulled from Config.plist key: "MorningEMA"
    private var surveyMorningURL: URL {
        guard let link = configPlist["MorningEMA"] as? String, !link.isEmpty,
              let url = URL(string: link) else {
            fatalError("MorningEMA missing/invalid in Config.plist. Add key 'MorningEMA' with a full https:// URL.")
        }
        return url
    }
    
    // Evening Qualtrics EMA URL pulled from Config.plist key: "EveningEMA"
    private var surveyEveningURL: URL {
        guard let link = configPlist["EveningEMA"] as? String, !link.isEmpty,
              let url = URL(string: link) else {
            fatalError("EveningEMA missing/invalid in Config.plist. Add key 'EveningEMA' with a full https:// URL.")
        }
        return url
    }

    // Setting up app state
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60 // setting standard bedtime (11:00 PM)
    @StateObject private var supabaseService = SupabaseService.shared // REVISIT: making supabase the core database

// Notification set up
    init() {
        // Setting the delegate early so taps work on cold start
        NotificationService.shared.configure()
    }

// Scene and root view: open some scene > what windows exist > contentview produces UI
    var body: some Scene {
        WindowGroup {
            ContentView() // my root UI
                .environmentObject(supabaseService) // makes supabase client available throughout the app
                .task { // task block asks users for notification permissions
                    let granted = await NotificationService.shared.requestAuthorization()
                    guard granted else { return }

                    // one-time guard checking if users already have allowed notifications
                    if !UserDefaults.standard.bool(forKey: "didScheduleNotifications") {
                        let uid = IdentityService.shared.userId

                        // scheduling morning EMA
                        NotificationService.shared.scheduleDailySurvey(
                            identifier: "EMA_Morning",
                            hour: 9, minute: 15,
                            baseURL: surveyMorningURL,
                            userId: uid,
                            title: "Morning Check-in",
                            body: "Quick 2-minute survey."
                        )

                        // scheduling evening EMA based on user set bedtime
                        NotificationService.shared.rescheduleEveningNotification(
                            bedtimeMinutes: bedtimeMinutes,
                            surveyURL: surveyEveningURL,
                            userId: uid
                        )

                        UserDefaults.standard.set(true, forKey: "didScheduleNotifications")
                    }
                }
                // if a user changes their bedtime later, this reschedules evening EMA to new bedtime
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
