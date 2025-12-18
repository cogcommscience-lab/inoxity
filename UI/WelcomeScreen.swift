//
//  WelcomeScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import SwiftUI

struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("INOXITY")
                    .font(.system(size: 32, weight: .light, design: .default))
                    .kerning(6)
                    .foregroundColor(.brandSecondary)
                    .padding(.bottom, 8)
                
                Text("Thank you for participating in our study! 🧠💤📱🗣️")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                Text("""
Momentarily, you will be prompted to share your sleep data with our research team. We intend to use this data anonymously to help advance understandings about sleep neuroscience, media studies, and communication processes.

By agreeing to share this valuable data with us, you are helping advance science!
""")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color.brandPrimary)
                    )
                    .foregroundColor(.brandBackground)
                    .shadow(radius: 6)
            }
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
