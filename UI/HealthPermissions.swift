//
//  PermissionsScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI
import HealthKit

struct PermissionScreen: View {
    private let healthStore = HKHealthStore()
    
    var onPermissionGranted: () -> Void
    var onPermissionDenied: () -> Void
    
    @AppStorage("hkAuthorized") private var hkAuthorized = false
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("INOXITY")
                    .font(.system(size: 32, weight: .light, design: .default))
                    .kerning(6)
                    .foregroundColor(.brandSecondary)
                    .padding(.bottom, 8)
                
                VStack(spacing: 16) {
                    Text("Allow Health Data Access")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("To track your sleep patterns and provide personalized insights, we need access to your Health app sleep data.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    requestHealthPermissions()
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView().tint(.brandBackground)
                        }
                        Text(isRequesting ? "Requesting…" : "Grant Permissions")
                    }
                    .fontWeight(.semibold)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .background(Capsule().fill(Color.brandPrimary))
                .foregroundColor(.brandBackground)
                .shadow(radius: 6)
                .padding(.horizontal)
                .disabled(isRequesting)
                
                Button {
                    hkAuthorized = false
                    onPermissionDenied()
                } label: {
                    Text("Continue without sharing sleep data")
                        .font(.callout)
                        .foregroundColor(.brandSecondary)
                }
                .disabled(isRequesting)
            }
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
    
    private func requestHealthPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            hkAuthorized = false
            onPermissionDenied()
            return
        }
        
        guard !isRequesting else { return }
        isRequesting = true
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let typesToRead: Set<HKObjectType> = [sleepType]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { _, error in
            // IMPORTANT:
            // Even if user taps "Don't Allow", HealthKit may call completion with error == nil.
            // So we MUST verify with a read query.
            if let error {
                DispatchQueue.main.async {
                    self.isRequesting = false
                    print("❌ HealthKit requestAuthorization error: \(error.localizedDescription)")
                    self.hkAuthorized = false
                    self.onPermissionDenied()
                }
                return
            }
            
            self.verifySleepReadAccess(sleepType: sleepType)
        }
    }
    
    private func verifySleepReadAccess(sleepType: HKCategoryType) {
        let calendar = Calendar.current
        let now = Date()
        
        // Use a wider window so we’re likely to find at least 1 sample if permission is granted
        let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { _, samples, error in
            DispatchQueue.main.async {
                self.isRequesting = false
                
                if let error = error {
                    print("🚫 Sleep read verification error -> DENIED: \(error.localizedDescription)")
                    self.hkAuthorized = false
                    self.onPermissionDenied()
                    return
                }
                
                let hasAtLeastOneSample = !(samples?.isEmpty ?? true)
                
                // Extra signal (sometimes helps): this can show denied/authorized even though it's "sharing" oriented.
                let status = self.healthStore.authorizationStatus(for: sleepType)
                let statusSaysAuthorized = (status == .sharingAuthorized)
                
                if hasAtLeastOneSample || statusSaysAuthorized {
                    print("✅ Verified sleep access (sample found OR status authorized).")
                    self.hkAuthorized = true
                    self.onPermissionGranted()
                } else {
                    // Key change: no error but no samples => treat as not granted (or at least not verifiable)
                    print("🚫 No error but no samples returned -> treat as DENIED for onboarding.")
                    self.hkAuthorized = false
                    self.onPermissionDenied()
                }
            }
        }
        
        healthStore.execute(query)
    }
}



