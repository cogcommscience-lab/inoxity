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
    @AppStorage("hkAuthorized") private var hkAuthorized = false

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
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("To track your sleep patterns and provide personalized insights, we need access to your Health app sleep data.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            Button("Grant Permissions", action: requestHealthPermissions)
                .fontWeight(.semibold)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color.brandPrimary)
                )
                .foregroundColor(.brandBackground)
                .shadow(radius: 6)
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

    private func requestHealthPermissions() {
        let types: Set = [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!]
        healthStore.requestAuthorization(toShare: [], read: types) { success, error in
            DispatchQueue.main.async {
                if success {
                    hkAuthorized = true
                    onPermissionGranted()
                } else {
                    print("❌ HealthKit permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}
