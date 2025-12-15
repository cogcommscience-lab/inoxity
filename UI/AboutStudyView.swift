//
//  AboutStudyView.swift
//  Inoxity
//
//  Created on 11/9/25.
//

import SwiftUI
import UIKit

struct AboutStudyView: View {
    @EnvironmentObject var supabase: SupabaseClient
    
    @State private var reason: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    
    private let qualtricsSurveyURL = URL(string: "https://your-real-qualtrics-link-here")!
    
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
                    
                    // Opt-out reason section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why are you leaving?")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        TextEditor(text: $reason)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.brandBackground.opacity(0.5))
                            )
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                            )
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
                    
                    // Opt-out buttons
                    VStack(spacing: 16) {
                        Button {
                            Task { await handleOptOut(deleteData: true) }
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
                        
                        Button {
                            Task { await handleOptOut(deleteData: false) }
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
        }
    }
    
    @MainActor
    private func handleOptOut(deleteData: Bool) async {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // ✅ Keep your existing logic EXACTLY
            try await supabase.optOut(
                deleteData: deleteData,
                reason: reason.isEmpty ? "No reason provided" : reason
            )
            
            // ✅ Only after success: open Qualtrics in external Safari
            UIApplication.shared.open(qualtricsSurveyURL, options: [:], completionHandler: nil)
            
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        
        isSubmitting = false
    }
}
