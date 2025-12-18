//
//  SleepSummary.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import SwiftUI
import HealthKit
import Charts


// MARK: Sleep Segment Data Structure

struct SleepSummaryView: View {
    let sleepSummary: SleepSummary
    let lastSyncedAt: Date?
    let sleepDataForDate: [SleepSegment]
    let selectedDate: Date
    let onDateChange: (Date) -> Void
    
    // Body
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Date Selector
                VStack(spacing: 8) {
                    Text("Sleep Summary")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    // Date Selector
                    HStack(spacing: 16) {
                        Button(action: {
                            let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            onDateChange(previousDate)
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.brandSecondary)
                                .font(.title3)
                        }
                        
                        Text(formatDateHeader(selectedDate))
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(minWidth: 120)
                        
                        Button(action: {
                            let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            if nextDate <= Date() {
                                onDateChange(nextDate)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date() > Date() ? .gray : .brandSecondary)
                                .font(.title3)
                        }
                        .disabled(Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date() > Date())
                    }
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
                
                // Charts - Always show, even if empty (will show empty state)
                SleepChartsView(sleepDataForDate: sleepDataForDate)
                
                // Sync Info
                if let syncTime = lastSyncedAt {
                    Text("Last refreshed: \(formatTime(syncTime))")
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
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}


// MARK: Charts Helper View
struct SleepChartsView: View {
    let sleepDataForDate: [SleepSegment]
    
    // Aggregate segments by stage
    private var stageData: [(stage: String, minutes: Double)] {
        var totals: [String: TimeInterval] = [:]
        
        for segment in sleepDataForDate {
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            totals[segment.stage, default: 0] += duration
        }
        
        return totals.map { (stage: $0.key, minutes: $0.value / 60.0) }
            .sorted { $0.stage < $1.stage }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Bar Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Duration by Stage")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                if stageData.isEmpty {
                    Text("No sleep data for this date")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    Chart(stageData, id: \.stage) { item in
                        BarMark(
                            x: .value("Stage", item.stage),
                            y: .value("Minutes", item.minutes)
                        )
                        .foregroundStyle(Color.brandSecondary)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(.white.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(.white.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
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
            
            // Pie/Donut Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Stage Proportions")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                if stageData.isEmpty {
                    Text("No sleep data for this date")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    if #available(iOS 17.0, *) {
                        Chart(stageData, id: \.stage) { item in
                            SectorMark(
                                angle: .value("Minutes", item.minutes),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(colorForStage(item.stage))
                            .annotation(position: .overlay) {
                                if item.minutes > 10 { // Only show annotation if segment is large enough
                                    Text(String(format: "%.0f", item.minutes))
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 250)
                        
                        // Custom Legend
                        HStack(spacing: 16) {
                            ForEach(stageData, id: \.stage) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(colorForStage(item.stage))
                                        .frame(width: 10, height: 10)
                                    Text(item.stage)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        // Fallback for iOS 16: use a simple list view
                        VStack(alignment: .leading, spacing: 8) {
                            let total = stageData.reduce(0) { $0 + $1.minutes }
                            ForEach(stageData, id: \.stage) { item in
                                HStack {
                                    Circle()
                                        .fill(Color.brandSecondary)
                                        .frame(width: 12, height: 12)
                                    Text(item.stage)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(String(format: "%.0f min (%.1f%%)", item.minutes, total > 0 ? (item.minutes / total) * 100 : 0))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
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
        }
    }
    
    private func colorForStage(_ stage: String) -> Color {
        switch stage {
        case "Deep":
            return .blue
        case "REM":
            return .purple
        case "Core":
            return .brandSecondary
        case "Awake":
            return .brandPrimary
        default:
            return .gray
        }
    }
}

// MARK: Wrapper view that loads sleep data for the Sleep Summary page
struct SleepSummaryPageView: View {
    @State private var sleepSummary: SleepSummary?
    @State private var sleepDataForDate: [SleepSegment] = []
    @State private var lastSyncedAt: Date?
    @State private var isLoading = true
    @State private var status = "Loading..."
    @State private var selectedDate: Date = {
        // Default to yesterday (last night)
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }()
    private let healthStore = HKHealthStore()
    
    var body: some View {
        Group {
            if let summary = sleepSummary {
                SleepSummaryView(
                    sleepSummary: summary,
                    lastSyncedAt: lastSyncedAt,
                    sleepDataForDate: sleepDataForDate,
                    selectedDate: selectedDate,
                    onDateChange: { newDate in
                        selectedDate = newDate
                        Task {
                            await loadSleepDataForDate(selectedDate)
                        }
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .brandSecondary))
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Text(isLoading ? "Loading sleep data..." : "No sleep data available")
                                .font(.title2)
                                .foregroundStyle(.white)
                            
                            if !isLoading {
                                Text(status)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
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
        }
        .task {
            await loadSleepDataForDate(selectedDate)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await loadSleepDataForDate(selectedDate)
                }
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    // Sleep query for a specific date (noon to noon)
    func loadSleepDataForDate(_ date: Date) async {
        isLoading = true
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let cal = Calendar.current
        let dateStart = cal.startOfDay(for: date)
        let windowEnd = cal.date(byAdding: .hour, value: 12, to: dateStart)!   // date at 12:00
        let windowStart = cal.date(byAdding: .day, value: -1, to: windowEnd)!   // previous day at 12:00
        let pred = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

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
            var segments: [SleepSegment] = []

            for s in samples {
                let start = max(s.startDate, windowStart)
                let end = min(s.endDate, windowEnd)
                guard end > start else { continue }
                let dur = end.timeIntervalSince(start)
                
                // Determine stage label
                let stage: String
                switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                case .asleepREM:
                    stage = "REM"
                    rem += dur
                case .asleepCore:
                    stage = "Core"
                    core += dur
                case .asleepDeep:
                    stage = "Deep"
                    deep += dur
                case .awake:
                    stage = "Awake"
                    awake += dur
                case .asleepUnspecified, .inBed, .none:
                    stage = "Core"
                    core += dur
                @unknown default:
                    stage = "Core"
                    core += dur
                }
                
                // Add segment
                segments.append(SleepSegment(
                    startTime: start,
                    endTime: end,
                    stage: stage
                ))
            }

            let totalAsleep = rem + core + deep

            await MainActor.run {
                self.sleepSummary = SleepSummary(
                    totalAsleepSec: totalAsleep,
                    remSec: rem, coreSec: core, deepSec: deep, awakeSec: awake,
                    windowStart: windowStart, windowEnd: windowEnd
                )
                self.sleepDataForDate = segments
                self.lastSyncedAt = Date()
                self.isLoading = false
                self.status = totalAsleep > 0 ? "Sleep data loaded" : "No sleep data found for this date"
            }
        } catch {
            await MainActor.run {
                self.sleepSummary = nil
                self.sleepDataForDate = []
                self.isLoading = false
                self.status = "Couldn't load sleep: \(error.localizedDescription)"
            }
        }
    }
}
