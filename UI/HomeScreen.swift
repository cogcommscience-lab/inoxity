//
//  HomeScreen.swift
//  Inoxity
//
//  Paste-ready version (tap-only streak, safe HK observer registration, upload feedback)
//

// Importing dependencies
import SwiftUI
import PhotosUI
import UIKit
import HealthKit
import UniformTypeIdentifiers

// MARK: Local model for the Home summary card
private struct HomeSleepSummary {
    let totalAsleepSec: TimeInterval
    let windowStart: Date
    let windowEnd: Date
}


// MARK: Reusable Status Chip
private struct StatusChip: View {
    let title: String
    let isDone: Bool
    var accent: Color = .brandSecondary

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(isDone ? accent.opacity(0.25) : .clear))
            .overlay(Capsule().stroke(accent, lineWidth: 1))
            .foregroundColor(isDone ? accent : .white.opacity(0.6))
    }
}


// MARK: Brand button style
private struct BrandPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.brandPrimary))
            .foregroundColor(.brandBackground)
            .shadow(radius: 6)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct HomeView: View {
    // Core state
    @State private var didStart = false
    @State private var status = "Ready"
    @State private var lastSyncedAt: Date?
    @State private var sleepSummary: HomeSleepSummary?

    // Upload picker state
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedImageExt: String?
    @State private var selectedImageMime: String?
    @State private var selectedVideoURL: URL?
    @State private var isUploading = false

    // Lightweight checklist state (persists)
    @AppStorage("didSleepToday") private var didSleepToday = false
    @AppStorage("didUploadToday") private var didUploadToday = false

    // Bedtime UI
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60
    @State private var showBedtimePicker = false
    @State private var selectedBedtime = Date()

    // Streak (tap-only) UI refresh
    @State private var refreshToken = UUID()

    // Streak count (computed + cached)
    @AppStorage("streakCount") private var streakCount = 0

    // HealthKit observer registration guard (IMPORTANT)
    @AppStorage("didRegisterHKObserver") private var didRegisterHKObserver = false

    @Environment(\.scenePhase) private var scenePhase

    private let healthStore = HKHealthStore()
    private let syncer = SleepSyncer()
    private var userId: UUID { IdentityService.shared.userId }

    // MARK: Tap-only survey completion dates (written by StreakManager)
    private var completedSurveyDates: Set<String> {
        // Force re-render when refreshToken changes
        let _ = refreshToken

        let array = UserDefaults.standard.stringArray(forKey: "completedSurveyDates") ?? []
        return Set(array)
    }

    private var didSurveyToday: Bool {
        completedSurveyDates.contains(dayKey(Date()))
    }

    // MARK: Subtitle
    private var subtitle: String {
        var actions: [String] = []
        if !didSurveyToday { actions.append("tap tonight’s reminder") }
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

    // Upload feedback
    @State private var showUploadAlert = false
    @State private var uploadAlertTitle = ""
    @State private var uploadAlertMessage = ""

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 80)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                content
                    .padding(.horizontal)

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

        // iOS 17+ friendly onChange
        .onChange(of: pickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task { await loadPickedItem(item) }
        }

        .task {
            // Initial load/sync
            rolloverIfNeeded()
            recalculateStreak()

            guard !didStart else { return }
            didStart = true

            status = "Initializing…"

            // First-time anchor flow
            if AnchorStore.load() == nil {
                status = "Backfilling last 30 days…"
                do {
                    try await syncer.backfill(userId: userId, days: 30)
                    try await syncer.primeAnchorToNow()
                } catch {
                    status = "Backfill failed (will retry later)"
                }
            }

            // Register observer ONCE
            if !didRegisterHKObserver {
                syncer.enableBackgroundDelivery(userId: userId)
                didRegisterHKObserver = true
            }

            // Do one incremental sync now
            status = "Syncing…"
            do {
                try await syncer.syncIncremental(userId: userId)
                lastSyncedAt = Date()
                status = "Up to date ✅"
            } catch {
                status = "Sync failed (will retry)"
            }

            await loadLastNightSummary()
            recalculateStreak()

            // Ensure bedtime picker reflects stored minutes
            updateSelectedBedtimeFromMinutes()

            // Refresh UI from stored survey dates (tap-only)
            refreshToken = UUID()
        }

        // iOS 17+ signature (single param)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                rolloverIfNeeded()
                recalculateStreak()
                refreshToken = UUID()

                Task {
                    status = "Syncing…"
                    do {
                        try await syncer.syncIncremental(userId: userId)
                        lastSyncedAt = Date()
                        status = "Up to date ✅"
                    } catch {
                        status = "Sync failed (will retry)"
                    }
                    await loadLastNightSummary()
                    recalculateStreak()
                }
            }
        }

        // Bedtime sheet
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
                        Button("Cancel") { showBedtimePicker = false }
                            .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let cal = Calendar.current
                            let hour = cal.component(.hour, from: selectedBedtime)
                            let minute = cal.component(.minute, from: selectedBedtime)
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

        .alert(uploadAlertTitle, isPresented: $showUploadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadAlertMessage)
        }
    }

    // MARK: Extracted content (UI)
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {

            // Sleep summary card
            if let s = sleepSummary {
                NavigationLink {
                    SleepSummaryPageView()
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

            // Bedtime card
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

            // Streak + checklist chips
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

            // Upload controls
            HStack(spacing: 12) {
                PhotosPicker(
                    "Upload Screen Time",
                    selection: $pickerItem,
                    matching: .any(of: [.images, .videos])
                )
                .buttonStyle(BrandPrimaryButtonStyle(isEnabled: true))

                Button(isUploading ? "Uploading…" : "Upload") {
                    Task { await uploadSelected() }
                }
                .buttonStyle(
                    BrandPrimaryButtonStyle(
                        isEnabled: !isUploading &&
                        (selectedImageData != nil || selectedVideoURL != nil || selectedImage != nil)
                    )
                )
                .disabled(
                    isUploading ||
                    (selectedImageData == nil && selectedVideoURL == nil && selectedImage == nil)
                )
            }

            // Preview selected media
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

            Text("Your data is stored securely and used only for research. *ST = Screen Time")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
    }
}

// MARK: - Logic & helpers
private extension HomeView {

    // Daily rollover: reset daily checklist flags at midnight
    func rolloverIfNeeded() {
        let today = dayKey(Date())
        let last = UserDefaults.standard.string(forKey: "lastDayKey") ?? ""
        if last != today {
            UserDefaults.standard.set(today, forKey: "lastDayKey")
            didSleepToday = false
            didUploadToday = false
        }
    }

    // Recalculate streak based ONLY on completedSurveyDates (tap-only)
    func recalculateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var current = today
        var count = 0

        // If today completed, start there; otherwise start from yesterday
        if !completedSurveyDates.contains(dayKey(today)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: today) else {
                streakCount = 0
                return
            }
            current = y
        }

        // Count backwards while consecutive days exist
        while completedSurveyDates.contains(dayKey(current)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = prev
        }

        streakCount = count
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
                let q = HKSampleQuery(
                    sampleType: type,
                    predicate: pred,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, result, error in
                    if let error = error { cont.resume(throwing: error); return }
                    cont.resume(returning: (result as? [HKCategorySample]) ?? [])
                }
                healthStore.execute(q)
            }

            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var deep: TimeInterval = 0

            for s in samples {
                let start = max(s.startDate, windowStart)
                let end = min(s.endDate, windowEnd)
                guard end > start else { continue }
                let dur = end.timeIntervalSince(start)

                switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                case .asleepREM:  rem  += dur
                case .asleepCore: core += dur
                case .asleepDeep: deep += dur
                case .awake:
                    break
                case .asleepUnspecified, .inBed, .none:
                    core += dur
                @unknown default:
                    core += dur
                }
            }

            let totalAsleep = rem + core + deep

            await MainActor.run {
                self.sleepSummary = HomeSleepSummary(
                    totalAsleepSec: totalAsleep,
                    windowStart: windowStart,
                    windowEnd: windowEnd
                )
                if totalAsleep > 0 {
                    didSleepToday = true
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
                } catch { /* fall through */ }
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
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mov")
                do {
                    try data.write(to: tmp)
                    selectedVideoURL = tmp
                    selectedImage = nil
                    selectedImageData = nil
                    selectedImageExt = nil
                    selectedImageMime = nil
                } catch { }
                return
            }
        }
    }

    func resetSelection() {
        pickerItem = nil
        selectedImage = nil
        selectedImageData = nil
        selectedImageExt = nil
        selectedImageMime = nil
        selectedVideoURL = nil
    }

    // Upload with user feedback + auto-close preview on success
    func uploadSelected() async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            if let data = selectedImageData,
               let ext = selectedImageExt,
               let mime = selectedImageMime {

                try await SupabaseService.shared.uploadImageDataAndRecord(data, ext: ext, mime: mime)

            } else if let img = selectedImage {

                try await SupabaseService.shared.uploadImageAndRecord(img)

            } else if let url = selectedVideoURL {

                try await SupabaseService.shared.uploadVideoAndRecord(fileURL: url)

            } else {
                throw NSError(
                    domain: "HomeView",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No media selected"]
                )
            }

            await MainActor.run {
                didUploadToday = true
                resetSelection()

                uploadAlertTitle = "Upload successful"
                uploadAlertMessage = "Thanks! Your Screen Time file was uploaded."
                showUploadAlert = true
            }

        } catch {
            await MainActor.run {
                uploadAlertTitle = "Upload failed"
                uploadAlertMessage = error.localizedDescription
                showUploadAlert = true
            }
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

        return ("jpg", "image/jpeg")
    }

    // Formatting helpers
    func formatHMS(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(Int(seconds))s"
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
        f.timeStyle = .short
        return f
    }()
}

