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
            Form {
                Section {
                    HStack {
                        Text("SONA ID")
                            .foregroundStyle(.primary)
                        Spacer()
                        if sonaId.isEmpty {
                            Text("Not set")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(sonaId)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                } header: {
                    Text("Research Information")
                } footer: {
                    Text("Your SONA ID is used to link your app data with research participation.")
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bedtime")
                                .font(.headline)
                            Text(formatBedtime())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Change") {
                            updateSelectedBedtimeFromMinutes()
                            showBedtimePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Sleep Schedule")
                } footer: {
                    Text("Your bedtime is used to schedule evening survey notifications.")
                }
            }
            .navigationTitle("Settings")
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
