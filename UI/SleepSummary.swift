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
                        .foregroundStyle(.white)
                    
                    Text("Last Night")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top)
                
                // Total Sleep Duration - Large Display
                VStack(spacing: 4) {
                    Text("Total Sleep")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formatHMS(sleepSummary.totalAsleepSec))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.vertical)
                
                // Sleep Stages Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sleep Stages")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    sleepStageRow(
                        title: "Deep Sleep",
                        duration: sleepSummary.deepSec,
                        color: .brandSecondary,
                        icon: "moon.zzz.fill"
                    )
                    
                    sleepStageRow(
                        title: "REM Sleep",
                        duration: sleepSummary.remSec,
                        color: .brandSecondary,
                        icon: "brain.head.profile"
                    )
                    
                    sleepStageRow(
                        title: "Core Sleep",
                        duration: sleepSummary.coreSec,
                        color: .brandSecondary,
                        icon: "bed.double.fill"
                    )
                    
                    sleepStageRow(
                        title: "Awake",
                        duration: sleepSummary.awakeSec,
                        color: .brandPrimary,
                        icon: "eye.fill"
                    )
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.brandBackground.opacity(0.7), Color.brandCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                
                // Sync Info
                if let syncTime = lastSyncedAt {
                    Text("Last synced: \(formatTime(syncTime))")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color.brandBackground, Color.brandBackground.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
                    .foregroundStyle(.white)
                
                HStack {
                    Text(formatHMS(duration))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("(\(String(format: "%.1f", percentage))%)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
