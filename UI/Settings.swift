//
//  Settings.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("bedtimeMinutes") private var bedtimeMinutes: Int = 23 * 60
    @AppStorage("sonaId") private var sonaId: String = ""
    
    @State private var showBedtimePicker = false
    @State private var selectedBedtime = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Research Information Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Research Information")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SONA ID")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            if sonaId.isEmpty {
                                Text("Not set")
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.brandCard.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Text(sonaId)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.brandCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
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
                    
                    // Sleep Schedule Card
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
                        
                        Text("Your bedtime is used to schedule evening survey notifications.")
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
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INOXITY")
                        .font(.system(size: 22, weight: .light, design: .default))
                        .kerning(4)
                        .foregroundColor(.brandSecondary)
                }
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
        }
    }
    
    private func formatBedtime() -> String {
        let hour = bedtimeMinutes / 60
        let minute = bedtimeMinutes % 60
        
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if let date = calendar.date(from: components) {
            return SettingsView.timeFormatter.string(from: date)
        }
        
        // Fallback formatting
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    private func updateSelectedBedtimeFromMinutes() {
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
}
