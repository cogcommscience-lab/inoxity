//
//  AboutStudyView.swift
//  Inoxity
//
//  Created on 11/9/25.
//

// Importing dependencies
import SwiftUI
import UIKit

// Pulling Qualtrics opt-out survey URL from Config.plist
enum AppConfig {
    static var OptOutURL: URL? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "QualtricsOptOutURL") as? String,
            !urlString.isEmpty
        else {
            return nil
        }
        return URL(string: urlString)
    }
}

// State
struct AboutStudyView: View {
    @EnvironmentObject var supabase: SupabaseService
    
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var optOutReason: String = ""
    
    // Confirmation UI state
    @State private var showConfirmDelete = false
    @State private var showConfirmKeep = false
    @State private var showSuccessAlert = false
    
    // Optional: open Qualtrics after opt-out (don’t crash if not configured)
    private let qualtricsSurveyURL = AppConfig.OptOutURL
    
    // Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title
                    Text("About This Study")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.top)
                    
                    // Study description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Study Description")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("This research study aims to understand sleep patterns and their relationship with daily activities. By participating, you're helping researchers gain valuable insights into sleep health and wellness. Your participation is voluntary, and you can opt out at any time.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandCard)
                    )
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    // Progress view
                    if isSubmitting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                            Text("Submitting your request…")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding()
                    }
                    
                    // Opt-out reason box
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Optional: Why are you leaving?")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("This feedback is stored separately and not linked to your identity. It may remain even if you delete your study data.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        TextEditor(text: $optOutReason)
                            .frame(minHeight: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandCard)
                    )
                    
                    // Opt-out buttons
                    VStack(spacing: 16) {
                        
                        Button {
                            showConfirmDelete = true
                        } label: {
                            Text("Opt out & delete my data")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                                .foregroundColor(.white)
                        }
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.6 : 1.0)
                        .confirmationDialog(
                            "Delete study data?",
                            isPresented: $showConfirmDelete,
                            titleVisibility: .visible
                        ) {
                            Button("Delete my data", role: .destructive) {
                                Task { await handleOptOut(deleteData: true) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently delete your uploaded data from the study database and storage.")
                        }
                        
                        Button {
                            showConfirmKeep = true
                        } label: {
                            Text("Opt out but keep my data")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.brandPrimary)
                                )
                                .foregroundColor(.brandBackground)
                        }
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.6 : 1.0)
                        .confirmationDialog(
                            "Opt out and keep existing data?",
                            isPresented: $showConfirmKeep,
                            titleVisibility: .visible
                        ) {
                            Button("Opt out", role: .destructive) {
                                Task { await handleOptOut(deleteData: false) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You’ll stop contributing new data, but your existing study data will remain included.")
                        }
                        
                    }
                    .padding(.horizontal)
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
            .alert("You're opted out", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your opt-out request was processed successfully.")
            }
        }
    }
    
    // Opt-out function
    @MainActor
    private func handleOptOut(deleteData: Bool) async {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // 1) Save opt-out reason FIRST (best-effort)
            do {
                try await supabase.submitOptOutFeedback(
                    reason: optOutReason,
                    deleteRequested: deleteData
                )
            } catch {
                // Don’t block opting out if feedback write fails
                print("⚠️ Failed to save opt-out reason: \(error.localizedDescription)")
            }
            
            // 2) Then process opt-out
            try await supabase.optOut(deleteData: deleteData)
            
            showSuccessAlert = true
            
            if let url = qualtricsSurveyURL {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                print("⚠️ QualtricsOptOutURL not configured in Config.plist")
            }
            
        } catch {
            print("❌ Opt-out failed:", error)
            errorMessage = "Something went wrong. Please try again."
        }
    }
}
