//
//  ContentView.swift
//  Tap Tap Track
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .track
    
    enum Tab {
        case track, history, manage
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case .track:
                    TrackView()
                case .history:
                    HistoryView()
                case .manage:
                    ManageView()
                }
            }
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "plus.circle.fill",
                title: "Track",
                isSelected: selectedTab == .track
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = .track
                }
            }
            
            TabBarButton(
                icon: "clock.arrow.circlepath",
                title: "History",
                isSelected: selectedTab == .history
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = .history
                }
            }
            
            TabBarButton(
                icon: "slider.horizontal.3",
                title: "Manage",
                isSelected: selectedTab == .manage
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = .manage
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e")!.opacity(0.98),
                    Color(hex: "#16213e")!.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#60A5FA")! : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#60A5FA")! : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}

