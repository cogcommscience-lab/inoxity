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
    @State private var uploadMessage = ""

    // MARK: - Lightweight streak state (persists)
    @AppStorage("streakCount") private var streakCount = 0
    @AppStorage("lastStreakDayKey") private var lastStreakDayKey = "" // "yyyy-MM-dd" of last increment
    @AppStorage("lastDayKey") private var lastDayKey = ""              // for daily rollover
    @AppStorage("didSleepToday") private var didSleepToday = false
    @AppStorage("didSurveyToday") private var didSurveyToday = false
    @AppStorage("didUploadToday") private var didUploadToday = false
    @AppStorage("sonaId") private var sonaId: String = ""
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60

    @State private var showBedtimePicker = false
    @State private var selectedBedtime = Date()

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
            todo = "You’re all set for today! 🎉"
        } else {
            let list = ListFormatter.localizedString(byJoining: actions) ?? actions.joined(separator: ", ")
            todo = "Don’t forget to \(list)!"
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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                // Your actual screen contents (whatever you put in `content`)
                content
                    .padding(.horizontal)

                // Keep some space at the bottom so it feels centered/balanced
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Inoxity")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        }
        // ---- top-level modifiers belong on the NavigationStack, not outside ----
        .onChange(of: pickerItem) { oldValue, newValue in
            guard let item = newValue else { return }
            Task { await loadPickedItem(item) }
        }
        .task {
            rolloverIfNeeded() // reset today's flags if we crossed midnight

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
            maybeBumpStreak()
        }
        .onChange(of: scenePhase) { oldPhase, phase in
            if phase == .active {
                rolloverIfNeeded()
                Task {
                    status = "Syncing…"
                    try? await SleepSyncer().syncIncremental(userId: userId)
                    lastSyncedAt = Date()
                    status = "Up to date ✅"
                    await loadLastNightSummary()
                    maybeBumpStreak()
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
                        .padding(.top)
                    
                    DatePicker("Bedtime", selection: $selectedBedtime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                    
                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showBedtimePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: selectedBedtime)
                            let minute = calendar.component(.minute, from: selectedBedtime)
                            bedtimeMinutes = hour * 60 + minute
                            showBedtimePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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
                            .foregroundStyle(.secondary)

                        Text(formatHMS(s.totalAsleepSec))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        if let end = lastSyncedAt {
                            Text("Checked for new sleep data at \(formatTime(end))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last night you slept for... 🌙💤")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("No sleep data yet")
                        .font(.headline)
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }

            // Bedtime Section
            Button {
                showBedtimePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your bedtime is set for")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(formatBedtime())
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
            .buttonStyle(.plain)

            // Streak badge + tiny checklist
            HStack {
                Label("\(streakCount)-day streak", systemImage: "star.fill")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 14) {
                    checklistItem(title: "Sleep", done: didSleepToday)
                    checklistItem(title: "Survey", done: didSurveyToday)
                    checklistItem(title: "ST*", done: didUploadToday)
                }
                .font(.footnote)
            }

            // Add / Upload controls
            HStack(spacing: 12) {
                PhotosPicker("Upload Screen Time",
                             selection: $pickerItem,
                             matching: .any(of: [.images, .videos]))
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.large)

                Button(isUploading ? "Uploading…" : "Upload") {
                    Task { await uploadSelected() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .controlSize(.large)
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

            if !uploadMessage.isEmpty {
                Text(uploadMessage)
                    .font(.footnote)
                    .foregroundStyle(uploadMessage.contains("Success") ? .green : .red)
            }

            // Trust statement
            Text("Your data is stored securely and used only for research.      * ST = Screen Time")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Logic & helpers
private extension HomeView {
    // Handle Qualtrics deep link redirect
    func handleQualtricsReturn(_ url: URL) {
        print("Received URL: \(url.absoluteString)")
        
        // Expect: inoxity://surveyComplete?type=...&sona=...&ts=...
        guard url.scheme == "inoxity" else {
            print("Unexpected scheme: \(url.scheme ?? "nil")")
            return
        }
        
        guard url.host == "surveyComplete" else {
            print("Unexpected host: \(url.host ?? "nil")")
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        let type = queryItems.first(where: { $0.name == "type" })?.value
        let sona = queryItems.first(where: { $0.name == "sona" })?.value
        let ts = queryItems.first(where: { $0.name == "ts" })?.value
        
        print("host = \(url.host ?? "nil"), type = \(type ?? "nil"), sona = \(sona ?? "nil"), ts = \(ts ?? "nil")")

        // optional: capture SONA
        if let s = sona, !s.isEmpty {
            sonaId = s
        }

        // We intentionally do NOT touch `lastDayKey` here.
        // Daily rollover remains owned by `rolloverIfNeeded()` on launch/foreground.
        didSurveyToday = true
        maybeBumpStreak()

        // optional: quick feedback for QA
        uploadMessage = "Survey recorded\(type.map { " (\($0))" } ?? "")."
        print("Qualtrics return handled: \(url.absoluteString)")
    }

    // Daily rollover: reset today's flags at midnight
    func rolloverIfNeeded() {
        let today = dayKey(Date())
        if lastDayKey != today {
            lastDayKey = today
            didSleepToday = false
            didSurveyToday = false
            didUploadToday = false
        }
    }

    // When all three tasks are done today, increment streak once
    func maybeBumpStreak() {
        guard didSleepToday && didSurveyToday && didUploadToday else { return }
        let today = dayKey(Date())
        if lastStreakDayKey != today {
            streakCount += 1
            lastStreakDayKey = today
        }
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
                    maybeBumpStreak()
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
                    uploadMessage = "Image selected."
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
                uploadMessage = "Image selected."
                return
            }

            uploadMessage = "Couldn’t load image."
            return
        }

        if isMovie {
            if let url = try? await item.loadTransferable(type: URL.self) {
                selectedVideoURL = url
                selectedImage = nil
                selectedImageData = nil
                selectedImageExt = nil
                selectedImageMime = nil
                uploadMessage = "Video selected."
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
                    uploadMessage = "Video selected."
                } catch {
                    uploadMessage = "Couldn’t prepare video."
                }
                return
            }

            uploadMessage = "Couldn’t load video."
            return
        }

        uploadMessage = "Unsupported media type."
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
        uploadMessage = ""
        defer { isUploading = false }

        do {
            if let data = selectedImageData,
               let ext = selectedImageExt,
               let mime = selectedImageMime {
                try await SupabaseClient.shared.uploadImageDataAndRecord(
                    data, ext: ext, mime: mime, userId: userId
                )
                uploadMessage = "Success: image uploaded."
                didUploadToday = true
                maybeBumpStreak()
                resetSelection()
            } else if let img = selectedImage {
                try await SupabaseClient.shared.uploadImageAndRecord(img, userId: userId)
                uploadMessage = "Success: image uploaded."
                didUploadToday = true
                maybeBumpStreak()
                resetSelection()
            } else if let url = selectedVideoURL {
                try await SupabaseClient.shared.uploadVideoAndRecord(fileURL: url, userId: userId)
                uploadMessage = "Success: video uploaded."
                didUploadToday = true
                maybeBumpStreak()
                resetSelection()
            } else {
                uploadMessage = "Nothing selected."
            }
        } catch {
            uploadMessage = "Upload failed: \(error.localizedDescription)"
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
