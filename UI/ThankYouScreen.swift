//
//  ThankYouScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct ThankYouScreen: View {
    var onContinue: () -> Void   // callback to pop or navigate home

    var body: some View {
        VStack {
            Text("Congratulations! 🥳")
                .font(.title)
                .padding()

            Text("""
            You've officially contributed to science!👩‍🔬

            Thank you for sharing your sleep data with us, to help us better serve you and others who are interested in optimizing sleep and media health.
            """)
                .multilineTextAlignment(.center)
                .padding()

            Button("Go to Home") { onContinue() }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding()
    }
}

#Preview {
    ThankYouScreen {
        // no-op for preview
    }
}
