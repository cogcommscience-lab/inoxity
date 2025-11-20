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
        VStack(spacing: 24) {
            Text("Set up your account")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 12) {
                Text("SONA ID")
                    .font(.headline)
                TextField("Enter your SONA ID", text: $sonaIdText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(10)

                Text("Average bedtime (this week)")
                    .font(.headline)
                DatePicker("Bedtime", selection: $bedtimeDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }

            Button(action: complete) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .controlSize(.large)
            .disabled(sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func complete() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
        let h = comps.hour ?? 23
        let m = comps.minute ?? 0
        let minutes = h * 60 + m
        onComplete(sonaIdText.trimmingCharacters(in: .whitespacesAndNewlines), minutes)
    }
}
