//
//  WelcomeScreen.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import SwiftUI

struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        VStack {
            Text("Thank you for participating in our study! 🧠💤📱🗣️")
                .font(.title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()

            Text("""
            Momentarily, you will be prompted to share your sleep data with our research team. We intend to use this data, anonymously, to help advance current understandings about sleep neuroscience, media studies, and communication processes.

            By agreeing to share this valuable data with us, you are helping advance science!
            """)
                .multilineTextAlignment(.center)
                .padding()

            Button(action: onContinue) {
                Text("Continue")
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}
