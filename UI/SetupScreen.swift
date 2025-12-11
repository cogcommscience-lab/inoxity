//
//  SetupScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct SetupScreen: View {
    @State private var sonaIdText: String
    @State private var bedtimeDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    var onComplete: (_ sonaId: String, _ bedtimeMinutes: Int) -> Void

    init(initialSonaId: String, initialBedtimeMinutes: Int, onComplete: @escaping (_ sonaId: String, _ bedtimeMinutes: Int) -> Void) {
        _sonaIdText = State(initialValue: initialSonaId)
        let minutes = max(0, min(23 * 60 + 59, initialBedtimeMinutes))
        let h = minutes / 60
        let m = minutes % 60
        let base = Calendar.current.startOfDay(for: Date())
        _bedtimeDate = State(initialValue: Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base)
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("INOXITY")
                    .font(.system(size: 32, weight: .light, design: .default))
                    .kerning(6)
                    .foregroundColor(.brandSecondary)
                    .padding(.bottom, 8)
                
                Text("Set up your account")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SONA ID")
                        .font(.headline)
                        .foregroundStyle(.white)
                    TextField("Enter your SONA ID", text: $sonaIdText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.brandSecondary.opacity(0.3), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Average bedtime (this week)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    DatePicker("Bedtime", selection: $bedtimeDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .background(
                            LinearGradient(
                                colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal)

            Spacer()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: complete) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandBackground))
                            .scaleEffect(0.8)
                    }
                    Text("Continue")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color.brandPrimary)
                )
                .foregroundColor(.brandBackground)
                .shadow(radius: 6)
            }
            .disabled(sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            .opacity(sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving ? 0.5 : 1)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func complete() {
        let trimmedID = sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let deviceUUID = DeviceIDProvider.shared.deviceUUID
        
        Task {
            do {
                try await SupabaseClient.shared.upsertParticipant(deviceUUID: deviceUUID, sonaID: trimmedID)
                
                // Save to UserDefaults on success
                UserDefaults.standard.set(trimmedID, forKey: "sonaId")
                
                // Proceed to next step
                await MainActor.run {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
                    let h = comps.hour ?? 23
                    let m = comps.minute ?? 0
                    let minutes = h * 60 + m
                    isSaving = false
                    onComplete(trimmedID, minutes)
                }
            } catch {
                print("Error saving SONA ID to Supabase: \(error)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save SONA ID. Please try again."
                }
            }
        }
    }
}
