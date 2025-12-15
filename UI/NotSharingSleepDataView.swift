//
//  NotSharingSleepDataView.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct NotSharingSleepDataView: View {
    var onContinue: () -> Void   // callback to navigate to setup/home

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
                    Text("Thanks for exploring Inoxity!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Thanks for exploring Inoxity! You're currently not sharing sleep data, which is totally fine. Privacy comes first. If you ever decide you'd like to contribute sleep data in the future, you can turn it on at any time:\nHealth App → Sleep Data → Data Sources & Access → Apps Allowed to Read Data → Inoxity → Toggle \"ON\". We're happy to have you with us either way.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
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
    NotSharingSleepDataView {
        // no-op for preview
    }
}
