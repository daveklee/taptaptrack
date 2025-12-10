//
//  AppBackground.swift
//  Tap Tap Track
//

import SwiftUI

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#4f46e5")!,
                Color(hex: "#7c3aed")!,
                Color(hex: "#1a1a2e")!
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}

struct DarkBackground: View {
    var body: some View {
        Color(hex: "#0f0f1a")!
            .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}

