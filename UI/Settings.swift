//
//  Settings.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import UserNotifications
import UIKit
import HealthKit

struct SettingsView: View {
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60
    @AppStorage("sonaId") private var sonaId: String = ""

    // Health (Sleep) status persisted across views
    @AppStorage("hkAuthorized") private var hkAuthorized = false

    @State private var showBedtimePicker = false
    @State private var selectedBedtime = Date()
    @State private var editingSonaId: String = ""
    @State private var isSavingSonaId = false
    @State private var sonaIdStatusMessage: String?
    
    // 5-6 digit restraint on SONA id
    @FocusState private var isSonaFocused: Bool

    private var isValidSonaId: Bool {
        let trimmed = editingSonaId.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.count == 5 || trimmed.count == 6) && trimmed.allSatisfy { $0.isNumber }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    // Notifications
    @State private var notificationsEnabled = false
    @State private var permissionStatusMessage: String? = nil

    // Health check UI
    @State private var isCheckingHealth = false

    @Environment(\.scenePhase) private var scenePhase
    private let healthStore = HKHealthStore()

    // Defining the notification identifier
    private let eveningNotifID = "inoxity.eveningSurveyReminder"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Permissions Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions & Alerts")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))

                        VStack(spacing: 12) {

                            // Health status row
                            statusRow(
                                title: "Health (Sleep Data)",
                                isOn: hkAuthorized,
                                onLabel: "Granted",
                                offLabel: "Not granted"
                            )

                            Button {
                                Task { await checkHealthStatus() }
                            } label: {
                                HStack {
                                    if isCheckingHealth {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .brandBackground))
                                            .scaleEffect(0.9)
                                    }
                                    Text(isCheckingHealth ? "Checking…" : "Check Health Status")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.brandPrimary)
                                .foregroundColor(.brandBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(isCheckingHealth)

                            // Health info (show different message based on status)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hkAuthorized ? "You’re sharing sleep data." : "You’re not sharing sleep data.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.85))

                                Text(
                                    hkAuthorized
                                    ? """
                                    You can turn this off at any time here:

                                    Health App → Sleep → Data Sources & Access → Apps Allowed to Read Data → Inoxity → Toggle OFF
                                    """
                                    : """
                                    Sharing sleep data is optional and completely up to you.

                                    If you ever want to enable it, you can manage access here:

                                    Health App → Sleep → Data Sources & Access → Apps Allowed to Read Data → Inoxity → Toggle ON
                                    """
                                )
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                            }

                            Divider().overlay(.white.opacity(0.15))

                            // Notifications status row
                            statusRow(
                                title: "Notifications",
                                isOn: notificationsEnabled,
                                onLabel: "On",
                                offLabel: "Off"
                            )

                            Button {
                                openAppSettings()
                            } label: {
                                Text(notificationsEnabled ? "Disable Notifications" : "Enable Notifications")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.brandPrimary)
                                    .foregroundColor(.brandBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            if let msg = permissionStatusMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBackground.opacity(0.6), Color.brandCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // MARK: Research Information Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Research Information")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("SONA ID")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

                            // 5–6 digit numeric-only input + number pad + Done button
                            TextField("5–6 digit SONA ID", text: $editingSonaId)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .focused($isSonaFocused)
                                .onChange(of: editingSonaId) { _, newValue in
                                    let digitsOnly = newValue.filter { $0.isNumber }
                                    editingSonaId = String(digitsOnly.prefix(6))  // max 6
                                }
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Done") {
                                            isSonaFocused = false
                                            dismissKeyboard()
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.brandCard)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            if let statusMessage = sonaIdStatusMessage {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(statusMessage.contains("Error") ? .red : .green)
                            }

                            Button {
                                saveSonaId()
                            } label: {
                                HStack {
                                    if isSavingSonaId {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .brandBackground))
                                            .scaleEffect(0.8)
                                    }
                                    Text("Save SONA ID")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.brandPrimary)
                                .foregroundColor(.brandBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            // Disable unless 5 or 6 digits (and not currently saving)
                            .disabled(!isValidSonaId || isSavingSonaId)
                            .opacity(!isValidSonaId || isSavingSonaId ? 0.5 : 1)
                        }

                        Text("Your SONA ID is used to link your app data with research participation.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBackground.opacity(0.6), Color.brandCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        // Optional: tap anywhere on the card to dismiss
                        isSonaFocused = false
                        dismissKeyboard()
                    }

                    
                    // MARK: Sleep Schedule Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Schedule")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bedtime")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))

                            Text(formatBedtime())
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.brandCard)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            updateSelectedBedtimeFromMinutes()
                            showBedtimePicker = true
                        } label: {
                            Text("Change")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.brandPrimary)
                                .foregroundColor(.brandBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Text("Notifications are scheduled 60 minutes before your bedtime.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBackground.opacity(0.6), Color.brandCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                editingSonaId = sonaId
                refreshNotificationStatus()
                Task { await checkHealthStatus() }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    refreshNotificationStatus()
                    Task { await checkHealthStatus() }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INOXITY")
                        .font(.system(size: 22, weight: .light))
                        .kerning(4)
                        .foregroundColor(.brandSecondary)
                }
            }
            .sheet(isPresented: $showBedtimePicker) {
                bedtimeSheet
            }
        }
    }

    // MARK: Health check (same approach as PermissionScreen)
    @MainActor
    private func checkHealthStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            hkAuthorized = false
            permissionStatusMessage = "Health data isn’t available on this device."
            return
        }

        isCheckingHealth = true
        defer { isCheckingHealth = false }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])

        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("🚫 Health check error:", error.localizedDescription)
                        hkAuthorized = false
                        permissionStatusMessage = "Sleep access not granted."
                        continuation.resume()
                        return
                    }

                    let hasSample = !(samples?.isEmpty ?? true)
                    let status = healthStore.authorizationStatus(for: sleepType)
                    let statusSaysAuthorized = (status == .sharingAuthorized)

                    if hasSample || statusSaysAuthorized {
                        hkAuthorized = true
                        permissionStatusMessage = "Sleep access is enabled."
                    } else {
                        hkAuthorized = false
                        permissionStatusMessage = "Sleep access not granted."
                    }

                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }

    // MARK: Notifications
    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled =
                    settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Reusable UI
    @ViewBuilder
    private func statusRow(title: String, isOn: Bool, onLabel: String, offLabel: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(isOn ? onLabel : offLabel)
                    .font(.caption)
                    .foregroundStyle(isOn ? .green : .red)
            }
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOn ? .green : .red)
                .font(.title3)
        }
        .padding(.vertical, 6)
    }

    // MARK: Bedtime helpers
    private func formatBedtime() -> String {
        let hour = bedtimeMinutes / 60
        let minute = bedtimeMinutes % 60

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if let date = Calendar.current.date(from: components) {
            return SettingsView.timeFormatter.string(from: date)
        }

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func updateSelectedBedtimeFromMinutes() {
        var components = DateComponents()
        components.hour = bedtimeMinutes / 60
        components.minute = bedtimeMinutes % 60
        if let date = Calendar.current.date(from: components) {
            selectedBedtime = date
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    // MARK: Save SONA
    private func saveSonaId() {
        let trimmedID = editingSonaId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        isSavingSonaId = true
        sonaIdStatusMessage = nil

        Task {
            do {
                try await SupabaseService.shared.upsertParticipant(sonaID: trimmedID)
                await MainActor.run {
                    sonaId = trimmedID
                    isSavingSonaId = false
                    sonaIdStatusMessage = "SONA ID saved"
                }
            } catch {
                await MainActor.run {
                    isSavingSonaId = false
                    sonaIdStatusMessage = "Error saving SONA ID"
                }
            }
        }
    }

    // MARK: Bedtime Sheet (NOW HAS SAVE)
    private var bedtimeSheet: some View {
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
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.brandBackground, Color.brandBackground.opacity(0.95)],
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
                    .foregroundColor(.white.opacity(0.85))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let hour = Calendar.current.component(.hour, from: selectedBedtime)
                        let minute = Calendar.current.component(.minute, from: selectedBedtime)

                        bedtimeMinutes = hour * 60 + minute
                        showBedtimePicker = false

                        Task { await rescheduleEveningNotification60MinBeforeBedtime() }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.brandPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Schedule daily notification 60 minutes before bedtime
    @MainActor
    private func rescheduleEveningNotification60MinBeforeBedtime() async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        let isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)

        guard isAuthorized else {
            permissionStatusMessage = "Notifications are off. Enable them in Settings to receive reminders."
            return
        }

        // Remove previous schedule for this reminder
        center.removePendingNotificationRequests(withIdentifiers: [eveningNotifID])

        // Compute fire time = bedtime - 60 minutes (wrap around midnight)
        let fireMinutes = (bedtimeMinutes - 60 + 1440) % 1440
        let fireHour = fireMinutes / 60
        let fireMinute = fireMinutes % 60

        var dateComponents = DateComponents()
        dateComponents.hour = fireHour
        dateComponents.minute = fireMinute

        let content = UNMutableNotificationContent()
        content.title = "INOXITY"
        content.body = "Reminder: your evening survey is coming up."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: eveningNotifID, content: content, trigger: trigger)

        do {
            try await center.add(request)
            permissionStatusMessage = "Updated: notifications scheduled 60 minutes before bedtime."
            print("✅ Scheduled daily notification at \(fireHour):\(String(format: "%02d", fireMinute))")
        } catch {
            permissionStatusMessage = "Failed to schedule notification: \(error.localizedDescription)"
            print("❌ Failed to schedule notification:", error)
        }
    }
}





