//
//  BrandColors.swift
//  Inoxity
//
//  Brand color palette extension
//

import SwiftUI

extension Color {
    static let brandBackground = Color(red: 0x21/255.0, green: 0x11/255.0, blue: 0x29/255.0)   // #211129
    static let brandPrimary    = Color(red: 0xF4/255.0, green: 0xAB/255.0, blue: 0xAF/255.0)   // #F4ABAF
    static let brandSecondary  = Color(red: 0x82/255.0, green: 0xD8/255.0, blue: 0xD8/255.0)   // #82D8D8
    static let brandCard       = Color.brandBackground.opacity(0.35) // subtle lighter tint for cards
}

