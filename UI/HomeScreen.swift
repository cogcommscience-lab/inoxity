//
//  HomeScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import PhotosUI
import UIKit
import HealthKit
import UniformTypeIdentifiers

// MARK: - Brand Colors Extension
extension Color {
    static let brandBackground = Color(red: 0x21/255.0, green: 0x11/255.0, blue: 0x29/255.0)   // #211129
    static let brandPrimary    = Color(red: 0xF4/255.0, green: 0xAB/255.0, blue: 0xAF/255.0)   // #F4ABAF
    static let brandSecondary  = Color(red: 0x82/255.0, green: 0xD8/255.0, blue: 0xD8/255.0)   // #82D8D8
    static let brandCard       = Color.brandBackground.opacity(0.35) // subtle lighter tint for cards
}

// MARK: - Simple model for the summary card
struct SleepSummary {
    let totalAsleepSec: TimeInterval
    let remSec: TimeInterval
    let coreSec: TimeInterval
    let deepSec: TimeInterval
    let awakeSec: TimeInterval
    let windowStart: Date
    let windowEnd: Date
}

// MARK: - Reusable Status Chip Component
struct StatusChip: View {
    let title: String
    let isDone: Bool
    var accent: Color = .brandSecondary

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(isDone ? accent.opacity(0.25) : .clear)
            )
            .overlay(
                Capsule().stroke(accent, lineWidth: 1)
            )
            .foregroundColor(isDone ? accent : .white.opacity(0.6))
    }
}

// MARK: - Custom Button Style for Brand Primary
struct BrandPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color.brandPrimary)
            )
            .foregroundColor(.brandBackground)
            .shadow(radius: 6)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct HomeView: View {
    // MARK: - Sleep + sync state
    @State private var didStart = false
    @State private var status = "Ready"
    @State private var lastSyncedAt: Date?
    @State private var sleepSummary: SleepSummary?   // filled after query

    // MARK: - Upload picker state
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImageExt: String?
    @State private var selectedImageMime: String?

    @State private var selectedVideoURL: URL?
    @State private var isUploading = false

    // MARK: - Lightweight streak state (persists)
    @AppStorage("streakCount") private var streakCount = 0
    @AppStorage("lastStreakDayKey") private var lastStreakDayKey = "" // "yyyy-MM-dd" of last increment
    @AppStorage("lastDayKey") private var lastDayKey = ""              // for daily rollover
    @AppStorage("didSleepToday") private var didSleepToday = false
    @AppStorage("didUploadToday") private var didUploadToday = false
    @AppStorage("sonaId") private var sonaId: String = ""
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60
    
    // Survey completion tracking: store completed dates as array of "yyyy-MM-dd" strings
    private var completedSurveyDates: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "completedSurveyDates") ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "completedSurveyDates")
        }
    }
    
    // Helper function to check if survey is completed today
    // Reads directly from UserDefaults to ensure we get the latest value
    private func checkSurveyCompletedToday() -> Bool {
        let today = dayKey(Date())
        let array = UserDefaults.standard.stringArray(forKey: "completedSurveyDates") ?? []
        let dates = Set(array)
        let result = dates.contains(today)
        print("🔍 checkSurveyCompletedToday: today=\(today), result=\(result), dates=\(Array(dates).sorted())")
        return result
    }
    
    // Computed property: check if survey is completed today
    // The surveyCompletionUpdateTrigger ensures SwiftUI refreshes when this changes
    private var didSurveyToday: Bool {
        // Access the trigger to make SwiftUI observe it
        let _ = surveyCompletionUpdateTrigger
        // Read directly from UserDefaults to get the latest value
        return checkSurveyCompletedToday()
    }

    @State private var showBedtimePicker = false
    @State private var selectedBedtime = Date()
    @State private var surveyCompletionUpdateTrigger = UUID() // Triggers view refresh when survey completion changes

    @Environment(\.scenePhase) private var scenePhase
    private let healthStore = HKHealthStore()
    private var userId: UUID { IdentityService.shared.userId }

    // ✅ Centered header subtitle (computed property lives at struct scope)
    private var subtitle: String {
        var actions: [String] = []
        if !didSurveyToday { actions.append("complete today’s survey") }
        if !didUploadToday { actions.append("upload Screen Time") }
        if !didSleepToday { actions.append("get a good night’s sleep") }

        let todo: String
        if actions.isEmpty {
            todo = "You're all set for today! 🎉"
        } else {
            let list = ListFormatter.localizedString(byJoining: actions)
            todo = "Don't forget to \(list)!"
        }

        let streak = streakCount > 0 ? " \(streakCount)-day streak! ⭐️" : ""
        return "Hey there! \(todo)\(streak)"
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Push content down a bit (tweak as you like)
                Spacer(minLength: 80)

                // Subtitle under the nav bar (can wrap freely)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                // Your actual screen contents (whatever you put in `content`)
                content
                    .padding(.horizontal)

                // Keep some space at the bottom so it feels centered/balanced
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INOXITY")
                        .font(.system(size: 22, weight: .light, design: .default))
                        .kerning(4)
                        .foregroundColor(.brandSecondary)
                }
            }
        }
        .tint(.brandPrimary)
        // ---- top-level modifiers belong on the NavigationStack, not outside ----
        .onChange(of: pickerItem) { oldValue, newValue in
            guard let item = newValue else { return }
            Task { await loadPickedItem(item) }
        }
        .task {
            rolloverIfNeeded() // reset today's flags if we crossed midnight
            recalculateStreak() // ensure streak is up to date on launch

            guard !didStart else { return }
            didStart = true
            status = "Initializing…"

            let syncer = SleepSyncer()
            if AnchorStore.load() == nil {
                status = "Backfilling last 30 days…"
                try? await syncer.backfill(userId: userId, days: 30)
                try? await syncer.primeAnchorToNow()
            }

            syncer.enableBackgroundDelivery(userId: userId)
            try? await syncer.syncIncremental(userId: userId)
            lastSyncedAt = Date()
            status = "Up to date ✅"

            await loadLastNightSummary()
            recalculateStreak()
        }
        .onChange(of: scenePhase) { oldPhase, phase in
            if phase == .active {
                rolloverIfNeeded()
                recalculateStreak() // ensure streak is up to date when app becomes active
                Task {
                    status = "Syncing…"
                    try? await SleepSyncer().syncIncremental(userId: userId)
                    lastSyncedAt = Date()
                    status = "Up to date ✅"
                    await loadLastNightSummary()
                    recalculateStreak()
                }
            }
        }
        .onOpenURL { url in
            handleQualtricsReturn(url)
        }
        .sheet(isPresented: $showBedtimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Set Your Bedtime")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(.top)
                    
                    DatePicker("Bedtime", selection: $selectedBedtime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showBedtimePicker = false
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: selectedBedtime)
                            let minute = calendar.component(.minute, from: selectedBedtime)
                            bedtimeMinutes = hour * 60 + minute
                            showBedtimePicker = false
                        }
                        .foregroundColor(.brandPrimary)
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(
                LinearGradient(
                    colors: [Color.brandBackground, Color.brandBackground.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .onAppear {
            updateSelectedBedtimeFromMinutes()
        }
    }

    // MARK: - Extracted content view (keeps body tidy)
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {

            // Sleep Summary Card
            if let s = sleepSummary {
                NavigationLink {
                    SleepSummaryView(sleepSummary: s, lastSyncedAt: lastSyncedAt)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last night you slept for... 🌙💤")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        Text(formatHMS(s.totalAsleepSec))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        if let end = lastSyncedAt {
                            Text("Checked for new sleep data at \(formatTime(end))")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last night you slept for... 🌙💤")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("No sleep data yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            }

            // Bedtime Section
            Button {
                showBedtimePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your bedtime is set for")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(formatBedtime())
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.callout)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            }
            .buttonStyle(.plain)

            // Streak badge + tiny checklist
            // Force SwiftUI to observe surveyCompletionUpdateTrigger by using it in the view
            let _ = surveyCompletionUpdateTrigger // Make SwiftUI observe this state change
            
            HStack(spacing: 8) {
                Text("\(streakCount)-day streak")
                    .font(.caption.bold())
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Color.brandPrimary.opacity(0.25)))
                    .foregroundColor(.brandPrimary)

                Spacer()

                HStack(spacing: 8) {
                    StatusChip(title: "Sleep",  isDone: didSleepToday,  accent: .brandSecondary)
                    StatusChip(title: "Survey", isDone: didSurveyToday, accent: .brandSecondary)
                    StatusChip(title: "ST*",    isDone: didUploadToday, accent: .brandSecondary)
                }
            }

            // Add / Upload controls
            HStack(spacing: 12) {
                PhotosPicker("Upload Screen Time",
                             selection: $pickerItem,
                             matching: .any(of: [.images, .videos]))
                    .buttonStyle(BrandPrimaryButtonStyle(isEnabled: true))

                Button(isUploading ? "Uploading…" : "Upload") {
                    Task { await uploadSelected() }
                }
                .buttonStyle(BrandPrimaryButtonStyle(
                    isEnabled: !isUploading &&
                    (selectedImageData != nil || selectedVideoURL != nil || selectedImage != nil)
                ))
                .disabled(
                    isUploading ||
                    (selectedImageData == nil && selectedVideoURL == nil && selectedImage == nil)
                )
            }

            // (Temporary) Mark survey done — replace with deep link later
            /*
            if !didSurveyToday {
                Button {
                    didSurveyToday = true
                    maybeBumpStreak()
                } label: {
                    Label("I completed my surveys today!", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }*/

            // Preview selected media (optional)
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)))
            } else if let url = selectedVideoURL {
                HStack(spacing: 10) {
                    Image(systemName: "video.fill")
                    Text(url.lastPathComponent).lineLimit(1)
                }
                .font(.callout)
                .padding(10)
                .background(.blue.opacity(0.1))
                .cornerRadius(10)
            }

            // Trust statement
            Text("Your data is stored securely and used only for research.      * ST = Screen Time")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
    }
}

// MARK: - Logic & helpers
private extension HomeView {
    // Handle Qualtrics deep link redirect
    func handleQualtricsReturn(_ url: URL) {
        print("🔗 Received deep link: \(url.absoluteString)")
        print("🔗 Current thread: \(Thread.isMainThread ? "Main" : "Background")")
        
        // Expect: inoxity://survey-complete?date=YYYY-MM-DD
        guard url.scheme == "inoxity" else {
            print("⚠️ Unexpected scheme: \(url.scheme ?? "nil")")
            return
        }
        
        guard url.host == "survey-complete" else {
            print("⚠️ Unexpected host: \(url.host ?? "nil"), expected 'survey-complete'")
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        // Parse date parameter or use today
        let dateString = queryItems.first(where: { $0.name == "date" })?.value
        let targetDate: Date
        
        if let dateStr = dateString {
            // Parse the provided date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.calendar = .current
            formatter.locale = .current
            formatter.timeZone = .current
            
            if let parsedDate = formatter.date(from: dateStr) {
                targetDate = parsedDate
                print("📅 Parsed date from URL: \(dateStr)")
            } else {
                print("⚠️ Could not parse date '\(dateStr)', using today")
                targetDate = Date()
            }
        } else {
            // No date provided, use today
            targetDate = Date()
            print("📅 No date parameter, using today")
        }
        
        // Mark survey as completed for the target date
        // onOpenURL is already called on the main thread, so we can call directly
        markSurveyCompleted(for: targetDate)
        
        // Optional: capture other query parameters if needed
        let sona = queryItems.first(where: { $0.name == "sona" })?.value
        
        if let s = sona, !s.isEmpty {
            sonaId = s
        }
        
        let dateKey = dayKey(targetDate)
        print("✅ Survey completion recorded for \(dateKey)")
    }
    
    /// Mark a survey as completed for a specific date
    /// This stores the completion date and recalculates the streak
    func markSurveyCompleted(for date: Date) {
        let dateKey = dayKey(date)
        var dates = completedSurveyDates
        dates.insert(dateKey)
        
        // Write directly to UserDefaults and synchronize to ensure it's written immediately
        UserDefaults.standard.set(Array(dates), forKey: "completedSurveyDates")
        UserDefaults.standard.synchronize() // Force immediate write (deprecated but still works)
        
        print("✅ Wrote to UserDefaults: \(Array(dates).sorted())")
        
        // CRITICAL: Update the trigger to force SwiftUI to refresh
        // This must happen AFTER the UserDefaults write
        surveyCompletionUpdateTrigger = UUID()
        
        // Verify the write was successful
        let verifyArray = UserDefaults.standard.stringArray(forKey: "completedSurveyDates") ?? []
        let verifySet = Set(verifyArray)
        print("✅ Verified UserDefaults contains: \(Array(verifySet).sorted())")
        print("✅ Today's date key: \(dayKey(Date()))")
        print("✅ Date key in set: \(verifySet.contains(dayKey(Date())))")
        
        // Recalculate streak based on consecutive survey completions
        recalculateStreak()
        
        print("✅ Marked survey completed for \(dateKey), trigger updated to \(surveyCompletionUpdateTrigger.uuidString.prefix(8))...")
    }
    
    /// Check if a survey was completed on a specific date
    func didCompleteSurvey(on date: Date) -> Bool {
        let dateKey = dayKey(date)
        return completedSurveyDates.contains(dateKey)
    }

    // Daily rollover: reset today's flags at midnight
    func rolloverIfNeeded() {
        let today = dayKey(Date())
        if lastDayKey != today {
            lastDayKey = today
            didSleepToday = false
            didUploadToday = false
            // Note: didSurveyToday is computed from completedSurveyDates, so no need to reset
        }
    }

    // Recalculate streak based on consecutive days with completed surveys
    func recalculateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Start from today and work backwards to find consecutive days
        var currentDate = today
        var consecutiveDays = 0
        
        // Check if today has a completed survey
        if didCompleteSurvey(on: currentDate) {
            consecutiveDays = 1
            
            // Count backwards for consecutive days
            while true {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                let previousDayKey = dayKey(previousDay)
                
                if completedSurveyDates.contains(previousDayKey) {
                    consecutiveDays += 1
                    currentDate = previousDay
                } else {
                    break
                }
            }
        } else {
            // Today doesn't have a survey, check backwards from yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                streakCount = 0
                return
            }
            
            if didCompleteSurvey(on: yesterday) {
                consecutiveDays = 1
                currentDate = yesterday
                
                // Count backwards for consecutive days
                while true {
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                    let previousDayKey = dayKey(previousDay)
                    
                    if completedSurveyDates.contains(previousDayKey) {
                        consecutiveDays += 1
                        currentDate = previousDay
                    } else {
                        break
                    }
                }
            }
        }
        
        streakCount = consecutiveDays
        print("📊 Streak recalculated: \(streakCount) days")
    }

    // Legacy function: When all three tasks are done today, increment streak once
    // This is kept for backward compatibility with sleep/upload tracking
    func maybeBumpStreak() {
        // Note: Streak is now based on survey completions only, not all three tasks
        // This function is kept for compatibility but recalculates based on surveys
        recalculateStreak()
    }

    func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    // Sleep query (yesterday noon → today noon)
    func loadLastNightSummary() async {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let windowEnd = cal.date(byAdding: .hour, value: 12, to: todayStart)!   // today at 12:00
        let windowStart = cal.date(byAdding: .day, value: -1, to: windowEnd)!   // yesterday at 12:00
        let pred = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        do {
            let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
                let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, result, error in
                    if let error = error { cont.resume(throwing: error); return }
                    cont.resume(returning: (result as? [HKCategorySample]) ?? [])
                }
                healthStore.execute(q)
            }

            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var deep: TimeInterval = 0
            var awake: TimeInterval = 0

            for s in samples {
                let start = max(s.startDate, windowStart)
                let end = min(s.endDate, windowEnd)
                guard end > start else { continue }
                let dur = end.timeIntervalSince(start)

                switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                case .asleepREM:        rem  += dur
                case .asleepCore:       core += dur
                case .asleepDeep:       deep += dur
                case .awake:            awake += dur
                case .asleepUnspecified, .inBed, .none:
                    core += dur
                @unknown default:
                    core += dur
                }
            }

            let totalAsleep = rem + core + deep

            await MainActor.run {
                self.sleepSummary = SleepSummary(
                    totalAsleepSec: totalAsleep,
                    remSec: rem, coreSec: core, deepSec: deep, awakeSec: awake,
                    windowStart: windowStart, windowEnd: windowEnd
                )
                if totalAsleep > 0 {
                    didSleepToday = true
                    // Note: Streak is now based on survey completions only
                }
            }
        } catch {
            await MainActor.run {
                self.sleepSummary = nil
                self.status = "Couldn’t load sleep: \(error.localizedDescription)"
            }
        }
    }

    // Media picking (HEIC/HEIF aware)
    func loadPickedItem(_ item: PhotosPickerItem) async {
        let types = item.supportedContentTypes
        let isImage = types.contains { $0.conforms(to: .image) }
        let isMovie = types.contains { $0.conforms(to: .movie) }

        if isImage {
            if let url = try? await item.loadTransferable(type: URL.self) {
                do {
                    let data = try Data(contentsOf: url)
                    let ext = url.pathExtension.lowercased()
                    let mime: String = {
                        if let m = UTType(filenameExtension: ext)?.preferredMIMEType { return m }
                        if ext == "heic" { return "image/heic" }
                        if ext == "heif" { return "image/heif" }
                        return "image/\(ext)"
                    }()

                    selectedImage = UIImage(data: data)
                    selectedVideoURL = nil
                    selectedImageData = data
                    selectedImageExt = ext.isEmpty ? "jpg" : ext
                    selectedImageMime = mime
                    return
                } catch {
                    // fall through to Data path
                }
            }

            if let data = try? await item.loadTransferable(type: Data.self) {
                let (ext, mime) = inferImageType(from: data)
                selectedImage = UIImage(data: data)
                selectedVideoURL = nil
                selectedImageData = data
                selectedImageExt = ext
                selectedImageMime = mime
                return
            }

            return
        }

        if isMovie {
            if let url = try? await item.loadTransferable(type: URL.self) {
                selectedVideoURL = url
                selectedImage = nil
                selectedImageData = nil
                selectedImageExt = nil
                selectedImageMime = nil
                return
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                do {
                    try data.write(to: tmp)
                    selectedVideoURL = tmp
                    selectedImage = nil
                    selectedImageData = nil
                    selectedImageExt = nil
                    selectedImageMime = nil
                } catch {
                    // Couldn't prepare video
                }
                return
            }
            return
        }
    }

    func resetSelection() {
        selectedImage = nil
        selectedImageData = nil
        selectedImageExt = nil
        selectedImageMime = nil
        selectedVideoURL = nil
    }

    // Upload
    func uploadSelected() async {
        isUploading = true
        defer { isUploading = false }

        do {
            if let data = selectedImageData,
               let ext = selectedImageExt,
               let mime = selectedImageMime {
                try await SupabaseClient.shared.uploadImageDataAndRecord(
                    data, ext: ext, mime: mime, userId: userId
                )
                didUploadToday = true
                // Note: Streak is now based on survey completions only
                resetSelection()
            } else if let img = selectedImage {
                try await SupabaseClient.shared.uploadImageAndRecord(img, userId: userId)
                didUploadToday = true
                // Note: Streak is now based on survey completions only
                resetSelection()
            } else if let url = selectedVideoURL {
                try await SupabaseClient.shared.uploadVideoAndRecord(fileURL: url, userId: userId)
                didUploadToday = true
                // Note: Streak is now based on survey completions only
                resetSelection()
            }
        } catch {
            // Upload failed
        }
    }

    // Type sniffing: HEIC/HEIF/PNG/JPEG/WEBP
    func inferImageType(from data: Data) -> (ext: String, mime: String) {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return ("jpg", "image/jpeg") } // JPEG
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return ("png", "image/png") } // PNG

        if data.count > 12,
           String(data: data[0..<4], encoding: .ascii) == "RIFF",
           String(data: data[8..<12], encoding: .ascii) == "WEBP" {
            return ("webp", "image/webp")
        }
        if data.count > 16,
           String(data: data[4..<8], encoding: .ascii) == "ftyp" {
            let brand = String(data: data[8..<12], encoding: .ascii)?.lowercased() ?? ""
            if brand.contains("heic") || brand.contains("heix") { return ("heic", "image/heic") }
            if brand.contains("heif") || brand.contains("mif1") { return ("heif", "image/heif") }
            if brand.contains("hevc") || brand.contains("hevx") { return ("heic", "image/heic") }
        }
        return ("jpg", "image/jpeg") // default
    }

    // Formatting
    func formatHMS(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    func formatTime(_ date: Date) -> String {
        HomeView.timeFormatter.string(from: date)
    }

    func formatBedtime() -> String {
        let hour = bedtimeMinutes / 60
        let minute = bedtimeMinutes % 60
        
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let date = calendar.date(from: components) {
            return HomeView.timeFormatter.string(from: date)
        }
        
        // Fallback formatting
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    func updateSelectedBedtimeFromMinutes() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = bedtimeMinutes / 60
        components.minute = bedtimeMinutes % 60
        if let date = calendar.date(from: components) {
            selectedBedtime = date
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short   // e.g., "7:43 AM"
        return f
    }()

    // Small checklist item view
    @ViewBuilder
    func checklistItem(title: String, done: Bool) -> some View {
        Label(title, systemImage: done ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(done ? .green : .secondary)
    }
}
