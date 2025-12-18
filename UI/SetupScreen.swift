//
//  SetupScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import UIKit

struct SetupScreen: View {
    @State private var sonaIdText: String
    @State private var bedtimeDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isSonaFocused: Bool

    // Add a done button to digit keypad
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    var onComplete: (_ sonaId: String, _ bedtimeMinutes: Int) -> Void

    init(
        initialSonaId: String,
        initialBedtimeMinutes: Int,
        onComplete: @escaping (_ sonaId: String, _ bedtimeMinutes: Int) -> Void
    ) {
        _sonaIdText = State(initialValue: initialSonaId)
        let minutes = max(0, min(23 * 60 + 59, initialBedtimeMinutes))
        let h = minutes / 60
        let m = minutes % 60
        let base = Calendar.current.startOfDay(for: Date())
        _bedtimeDate = State(
            initialValue: Calendar.current.date(
                bySettingHour: h,
                minute: m,
                second: 0,
                of: base
            ) ?? base
        )
        self.onComplete = onComplete
    }

    // MARK: Validation
    private var trimmedSonaId: String {
        sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidSonaId: Bool {
        (trimmedSonaId.count == 5 || trimmedSonaId.count == 6)
        && trimmedSonaId.allSatisfy { $0.isNumber }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("INOXITY")
                    .font(.system(size: 32, weight: .light))
                    .kerning(6)
                    .foregroundColor(.brandSecondary)
                    .padding(.bottom, 8)

                Text("Set up your account")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 16) {

                // MARK: SONA ID
                VStack(alignment: .leading, spacing: 8) {
                    Text("SONA ID")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("5–6 digit SONA ID", text: $sonaIdText)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isSonaFocused)
                        .onChange(of: sonaIdText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            sonaIdText = String(filtered.prefix(6))
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
                        .onTapGesture {
                            isSonaFocused = false
                            dismissKeyboard()
                        }
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.brandBackground.opacity(0.7),
                                    Color.brandCard
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                            .stroke(
                                isValidSonaId || sonaIdText.isEmpty
                                ? Color.brandSecondary.opacity(0.3)
                                : Color.red.opacity(0.8),
                                lineWidth: 1
                            )
                        )

                    if !sonaIdText.isEmpty && !isValidSonaId {
                        Text("SONA ID must be 5 or 6 digits.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // MARK: Bedtime
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average bedtime (this week)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    DatePicker(
                        "Bedtime",
                        selection: $bedtimeDate,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.brandBackground.opacity(0.7),
                                Color.brandCard
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )
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

            // MARK: Continue Button
            Button(action: complete) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(
                                    tint: .brandBackground
                                )
                            )
                            .scaleEffect(0.8)
                    }
                    Text("Continue")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color.brandPrimary))
                .foregroundColor(.brandBackground)
                .shadow(radius: 6)
            }
            .disabled(!isValidSonaId || isSaving)
            .opacity(!isValidSonaId || isSaving ? 0.5 : 1)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color.brandBackground,
                    Color.brandBackground.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: Save
    private func complete() {
        guard isValidSonaId else {
            errorMessage = "SONA ID must be 5 or 6 digits."
            return
        }

        Task {
            await MainActor.run {
                isSaving = true
                errorMessage = nil
            }

            do {
                try await SupabaseService.shared.ensureAnonymousSession()
                try await SupabaseService.shared.upsertParticipant(sonaID: trimmedSonaId)

                UserDefaults.standard.set(trimmedSonaId, forKey: "sonaId")

                let comps = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: bedtimeDate
                )
                let h = comps.hour ?? 23
                let m = comps.minute ?? 0
                let minutes = h * 60 + m

                await MainActor.run {
                    isSaving = false
                    onComplete(trimmedSonaId, minutes)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save SONA ID. Please try again."
                }
            }
        }
    }
}

