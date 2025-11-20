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
        VStack {
            Text("Allow Health Data Access").font(.title).padding()
            Button("Grant Permissions", action: requestHealthPermissions)
                .padding()
                .background(Color.pink)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
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
