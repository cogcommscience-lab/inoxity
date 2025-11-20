//
//  SleepSummary.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import HealthKit

struct SleepSummaryView: View {
    let sleepSummary: SleepSummary
    let lastSyncedAt: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Sleep Summary")
                        .font(.largeTitle.bold())
                    
                    Text("Last Night")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Total Sleep Duration - Large Display
                VStack(spacing: 4) {
                    Text("Total Sleep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatHMS(sleepSummary.totalAsleepSec))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.vertical)
                
                // Sleep Stages Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sleep Stages")
                        .font(.title2.bold())
                    
                    sleepStageRow(
                        title: "Deep Sleep",
                        duration: sleepSummary.deepSec,
                        color: .blue,
                        icon: "moon.zzz.fill"
                    )
                    
                    sleepStageRow(
                        title: "REM Sleep",
                        duration: sleepSummary.remSec,
                        color: .purple,
                        icon: "brain.head.profile"
                    )
                    
                    sleepStageRow(
                        title: "Core Sleep",
                        duration: sleepSummary.coreSec,
                        color: .green,
                        icon: "bed.double.fill"
                    )
                    
                    sleepStageRow(
                        title: "Awake",
                        duration: sleepSummary.awakeSec,
                        color: .orange,
                        icon: "eye.fill"
                    )
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Sleep Window
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sleep Window")
                        .font(.title2.bold())
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bedtime")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(formatDateTime(sleepSummary.windowStart))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Wake Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(formatDateTime(sleepSummary.windowEnd))
                                .font(.headline)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Sync Info
                if let syncTime = lastSyncedAt {
                    Text("Last synced: \(formatTime(syncTime))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func sleepStageRow(title: String, duration: TimeInterval, color: Color, icon: String) -> some View {
        let total = sleepSummary.totalAsleepSec + sleepSummary.awakeSec
        let percentage = total > 0 ? (duration / total) * 100 : 0
        
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                HStack {
                    Text(formatHMS(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("(\(String(format: "%.1f", percentage))%)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func formatHMS(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
