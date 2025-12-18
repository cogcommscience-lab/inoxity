//
//  ThankYouScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import SwiftUI

struct ThankYouScreen: View {
    var onContinue: () -> Void   // callback to continue

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
                    Text("Congratulations! 🥳")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("""
You've officially contributed to science! 👩‍🔬

Thank you for sharing your sleep data with us, to help us better serve you and others who are interested in optimizing sleep and media health.
""")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal)
                }
            }

            Spacer()

            Button("Continue") { onContinue() }
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
}

#Preview {
    ThankYouScreen {
        // no-op for preview
    }
}

