//
//  ContentView.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    enum Screen { case welcome, permission, thankYou, setup, home }
    enum NavigationDestination { case home, settings }

    @State private var screen: Screen = .welcome
    @State private var selectedDestination: NavigationDestination? = .home
    @AppStorage("sonaId") private var sonaId: String = ""
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60 // default 11:00 PM
    @AppStorage("hkAuthorized") private var hkAuthorized = false  // lives INSIDE the view
    private let healthStore = HKHealthStore()

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeScreen { screen = .permission }
            case .permission:
                PermissionScreen { screen = .thankYou }
            case .thankYou:
                ThankYouScreen { screen = .setup }
            case .setup:
                SetupScreen(
                    initialSonaId: sonaId,
                    initialBedtimeMinutes: bedtimeMinutes,
                    onComplete: { id, minutes in
                        sonaId = id
                        bedtimeMinutes = minutes
                        screen = .home
                    }
                )
            case .home:
                NavigationSplitView {
                    SidebarView(selectedDestination: $selectedDestination)
                } detail: {
                    Group {
                        if selectedDestination == .home {
                            HomeView()
                        } else if selectedDestination == .settings {
                            SettingsView()
                        } else {
                            HomeView()
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .task {
            // Ask HealthKit whether requesting is necessary.
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let readSet: Set<HKObjectType> = [sleep]

            let status = await withCheckedContinuation {
                (cont: CheckedContinuation<HKAuthorizationRequestStatus, Never>) in
                healthStore.getRequestStatusForAuthorization(toShare: [], read: readSet) { status, _ in
                    cont.resume(returning: status)
                }
            }

            if status == .unnecessary {
                hkAuthorized = true
                screen = .home
            } else {
                hkAuthorized = false
                screen = .welcome
            }
        }
    }
}

struct SidebarView: View {
    @Binding var selectedDestination: ContentView.NavigationDestination?
    
    var body: some View {
        List(selection: $selectedDestination) {
            NavigationLink(value: ContentView.NavigationDestination.home) {
                Label("Home", systemImage: "house.fill")
            }
            
            NavigationLink(value: ContentView.NavigationDestination.settings) {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .navigationTitle("Inoxity")
    }
}
