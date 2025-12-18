//
//  ThankYouDenied.swift
//  Inoxity
//
//  Created by Rachael Kee on 12/15/25.
//

// Importing dependencies
import SwiftUI

struct ThankYouDenied: View {

    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Text("INOXITY")
                    .font(.system(size: 32, weight: .light))
                    .kerning(6)
                    .foregroundColor(.brandSecondary)

                Text("Thanks for Exploring Inoxity")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("""
You’re currently not sharing sleep data — and that’s completely okay.

Privacy comes first. You can still explore the app and set things up as normal.

If you ever decide you’d like to contribute sleep data in the future, you can turn it on at any time:
""")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    Text("Health App → Sleep Data")
                    Text("Data Sources & Access")
                    Text("Apps Allowed to Read Data → Inoxity → Toggle ON")
                }
                .font(.callout)
                .foregroundColor(.brandSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

                Text("We’re happy to have you with us either way.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)
            }

            Spacer()

            Button("Continue Setup") {
                onContinue()
            }
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
