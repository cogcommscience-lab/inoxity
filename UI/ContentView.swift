//
//  ContentView.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct ContentView: View {

    // MARK: Navigation enums
    enum Screen {
        case welcome
        case permission
        case thankYouAllowed
        case thankYouDenied
        case setup
        case home
    }

    enum NavigationDestination {
        case home
        case aboutStudy
        case sleepSummary
        case settings
    }

    // MARK: State
    @State private var screen: Screen = .welcome
    @State private var selectedDestination: NavigationDestination? = .home

    @AppStorage("sonaId") private var sonaId: String = ""
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60 // default 11:00 PM
    @AppStorage("hkAuthorized") private var hkAuthorized = false
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @AppStorage("didDecideHealth") private var didDecideHealth = false

    // Prevent repeating bootstrap work
    @State private var didBootstrap = false

    // MARK: Body
    var body: some View {
        Group {
            switch screen {

            case .welcome:
                WelcomeScreen {
                    screen = .permission
                }

            case .permission:
                PermissionScreen(
                    onPermissionGranted: {
                        // Don’t trust the callback (some implementations call "granted" after request returns)
                        didDecideHealth = true
                        routeAfterHealthDecision()
                    },
                    onPermissionDenied: {
                        // Same: treat as “decision made” and route based on stored hkAuthorized
                        didDecideHealth = true
                        routeAfterHealthDecision()
                    }
                )

            case .thankYouAllowed:
                ThankYouScreen {
                    screen = .setup
                }

            case .thankYouDenied:
                ThankYouDenied {
                    screen = .setup
                }

            case .setup:
                SetupScreen(
                    initialSonaId: sonaId,
                    initialBedtimeMinutes: bedtimeMinutes,
                    onComplete: { id, minutes in
                        sonaId = id
                        bedtimeMinutes = minutes
                        didFinishOnboarding = true
                        screen = .home
                    }
                )

            case .home:
                NavigationSplitView {
                    SidebarView(selectedDestination: $selectedDestination)
                } detail: {
                    switch selectedDestination {
                    case .home:
                        HomeView()
                    case .aboutStudy:
                        AboutStudyView()
                    case .sleepSummary:
                        SleepSummaryPageView()
                    case .settings:
                        SettingsView()
                    case .none:
                        HomeView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .onAppear {
            // Decide the correct start screen on every launch
            if didFinishOnboarding {
                screen = .home
            } else if didDecideHealth {
                screen = .setup
            } else {
                screen = .welcome
            }
        }
        .task {
            // Bootstrap Supabase anonymous auth session once per app run
            guard !didBootstrap else { return }
            didBootstrap = true

            do {
                try await SupabaseService.shared.ensureAnonymousSession()
            } catch {
                print("❌ Failed to start anonymous Supabase session: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Routing helper
    private func routeAfterHealthDecision() {
        // IMPORTANT:
        // This assumes PermissionScreen correctly writes hkAuthorized based on the real authorization result.
        // If it doesn't, then fix PermissionScreen (see note below).
        screen = hkAuthorized ? .thankYouAllowed : .thankYouDenied
    }

    // MARK: Sidebar
    struct SidebarView: View {
        @Binding var selectedDestination: ContentView.NavigationDestination?

        var body: some View {
            List(selection: $selectedDestination) {

                NavigationLink(value: ContentView.NavigationDestination.home) {
                    Label("Home", systemImage: "house.fill")
                        .foregroundColor(.white)
                }
                .listRowBackground(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                NavigationLink(value: ContentView.NavigationDestination.aboutStudy) {
                    Label("About This Study", systemImage: "info.circle.fill")
                        .foregroundColor(.white)
                }
                .listRowBackground(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                NavigationLink(value: ContentView.NavigationDestination.sleepSummary) {
                    Label("Sleep Summary", systemImage: "moon.zzz.fill")
                        .foregroundColor(.white)
                }
                .listRowBackground(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                NavigationLink(value: ContentView.NavigationDestination.settings) {
                    Label("Settings", systemImage: "gearshape.fill")
                        .foregroundColor(.white)
                }
                .listRowBackground(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .listStyle(.insetGrouped)
            .background(
                LinearGradient(
                    colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scrollContentBackground(.hidden)
            .tint(.brandPrimary)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INOXITY")
                        .font(.system(size: 22, weight: .light, design: .default))
                        .kerning(4)
                        .foregroundColor(.brandSecondary)
                }
            }
        }
    }
}


