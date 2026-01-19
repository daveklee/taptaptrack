//
//  OnboardingFlowView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Binding var hasSeenOnboarding: Bool
    @Binding var onboardingRequested: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \EventPreset.createdAt) private var presets: [EventPreset]

    private enum Step: Int, CaseIterable {
        case welcome
        case homePreview
        case suggestions
        case categories
        case customTaps
    }

    @State private var step: Step = .welcome
    @State private var animateHero = false
    @State private var selectedSuggestions: Set<String>
    @State private var didAddSuggestedPresets = false
    @State private var showingAddPresetSheet = false

    init(hasSeenOnboarding: Binding<Bool>, onboardingRequested: Binding<Bool>) {
        _hasSeenOnboarding = hasSeenOnboarding
        _onboardingRequested = onboardingRequested
        _selectedSuggestions = State(
            initialValue: Set(Self.suggestedPresets.filter { $0.isRecommended }.map(\.id))
        )
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                onboardingHeader

                TabView(selection: $step) {
                    welcomeStep
                        .tag(Step.welcome)
                    homePreviewStep
                        .tag(Step.homePreview)
                    suggestionsStep
                        .tag(Step.suggestions)
                    categoriesStep
                        .tag(Step.categories)
                    customTapsStep
                        .tag(Step.customTaps)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

                onboardingFooter
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingAddPresetSheet) {
            AddPresetSheet { name, iconName, colorHex, category, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled in
                let preset = EventPreset(
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex,
                    category: category,
                    numberEnabled: numberEnabled,
                    numberMin: numberMin,
                    numberMax: numberMax,
                    numberAllowDecimals: numberAllowDecimals,
                    numberRequired: numberRequired,
                    locationTrackingEnabled: locationTrackingEnabled
                )
                modelContext.insert(preset)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateHero = true
            }
        }
    }

    private var onboardingHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button("Skip") {
                    finishOnboarding()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 20)

            OnboardingProgressDots(currentIndex: step.rawValue, total: Step.allCases.count)
        }
    }

    private var onboardingFooter: some View {
        HStack(spacing: 14) {
            if step != .welcome {
                Button("Back") {
                    withAnimation {
                        step = Step(rawValue: step.rawValue - 1) ?? step
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button(nextButtonTitle) {
                handlePrimaryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var nextButtonTitle: String {
        switch step {
        case .customTaps:
            return "Finish Setup"
        case .suggestions:
            return didAddSuggestedPresets ? "Next" : "Add Selected"
        default:
            return "Next"
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .suggestions:
            if !didAddSuggestedPresets {
                addSelectedPresets()
            } else {
                goForward()
            }
        case .customTaps:
            finishOnboarding()
        default:
            goForward()
        }
    }

    private func goForward() {
        withAnimation {
            if let next = Step(rawValue: step.rawValue + 1) {
                step = next
            }
        }
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
        onboardingRequested = false
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 120, height: 120)

                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(animateHero ? 1.0 : 0.7)
                            .opacity(animateHero ? 1.0 : 0.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateHero)
                    }

                    Text("Welcome to Tap Tap Track -- the app that can help you track anything with a tap!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text("Let's set up your first taps and show you how quick logging can be.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 12)

                OnboardingTipCard(
                    icon: "bolt.fill",
                    title: "One tap = one event",
                    message: "Tap any preset to log it instantly. Add notes or details later if you want."
                )
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var homePreviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("This is your home screen. With one tap, you can log that any of these things happened -- a commute to the office, taking some medication, visiting a restaurant, or anything you want!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)

                OnboardingHomePreview()
                    .padding(.horizontal, 20)

                OnboardingTipCard(
                    icon: "sparkles",
                    title: "Fast and flexible",
                    message: "Your taps can be anything -- habits, routines, or moments you want to remember."
                )
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var suggestionsStep: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Would you like to add any of these common taps to your home screen?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)

                Text("Based on popular habit tracking ideas like hydration, medication, movement, and mood check-ins, pick a few to get started.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(Self.suggestedPresets) { preset in
                        SuggestedPresetRow(
                            preset: preset,
                            isSelected: selectedSuggestions.contains(preset.id)
                        ) {
                            toggleSuggestion(preset)
                        }
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button("Select All") {
                        selectedSuggestions = Set(Self.suggestedPresets.map(\.id))
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Clear") {
                        selectedSuggestions.removeAll()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var categoriesStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Categories are ways to help group your taps together to make them easier to find. When you add a new tap preset, you can also pick a category (or make a new one).")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Text("Examples")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    HStack(spacing: 10) {
                        OnboardingCategoryChip(title: "Health", colorHex: "#EC4899")
                        OnboardingCategoryChip(title: "Personal", colorHex: "#8B5CF6")
                        OnboardingCategoryChip(title: "Work", colorHex: "#6366F1")
                    }

                    HStack(spacing: 10) {
                        OnboardingCategoryChip(title: "Social", colorHex: "#14B8A6")
                        OnboardingCategoryChip(title: "Life", colorHex: "#60A5FA")
                    }
                }
                .padding(.horizontal, 20)

                OnboardingTipCard(
                    icon: "folder.fill",
                    title: "Stay organized",
                    message: "Use categories so your home screen stays tidy as your tap list grows."
                )
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var customTapsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Would you like to configure any other taps now?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("If you want, we can walk through the full tap preset setup next. You can also do this later from Manage.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("Add a Custom Tap") {
                    showingAddPresetSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)

                Button("Not Now") {
                    finishOnboarding()
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 40)
            }
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func toggleSuggestion(_ preset: SuggestedPreset) {
        if selectedSuggestions.contains(preset.id) {
            selectedSuggestions.remove(preset.id)
        } else {
            selectedSuggestions.insert(preset.id)
        }
    }

    private func addSelectedPresets() {
        guard !selectedSuggestions.isEmpty else {
            didAddSuggestedPresets = true
            goForward()
            return
        }

        let existingNames = Set(presets.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let maxOrder = categories.map { $0.order }.max() ?? -1
        var nextOrder = maxOrder + 1
        var createdCategories: [String: Category] = [:]

        for preset in Self.suggestedPresets where selectedSuggestions.contains(preset.id) {
            let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if existingNames.contains(trimmedName.lowercased()) {
                continue
            }

            let category = findOrCreateCategory(
                named: preset.categoryName,
                orderHint: &nextOrder,
                createdCategories: &createdCategories
            )
            let newPreset = EventPreset(
                name: trimmedName,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                category: category
            )
            modelContext.insert(newPreset)
        }

        didAddSuggestedPresets = true
        goForward()
    }

    private func findOrCreateCategory(
        named name: String,
        orderHint: inout Int,
        createdCategories: inout [String: Category]
    ) -> Category? {
        let key = name.lowercased()
        if let cached = createdCategories[key] {
            return cached
        }

        if let existing = categories.first(where: { $0.name.lowercased() == key }) {
            return existing
        }

        let colorHex = Self.categoryColors[name, default: "#60A5FA"]
        let newCategory = Category(name: name, colorHex: colorHex, locationTrackingEnabled: false, order: orderHint)
        orderHint += 1
        modelContext.insert(newCategory)
        createdCategories[key] = newCategory
        return newCategory
    }

    private static let categoryColors: [String: String] = [
        "Work": "#6366F1",
        "Personal": "#8B5CF6",
        "Health": "#EC4899",
        "Social": "#14B8A6",
        "Life": "#60A5FA"
    ]

    private static let suggestedPresets: [SuggestedPreset] = [
        SuggestedPreset(
            id: "Commute",
            name: "Commute",
            iconName: "car.fill",
            colorHex: "#6366F1",
            categoryName: "Work",
            description: "Log trips to the office or travel days.",
            isRecommended: true
        ),
        SuggestedPreset(
            id: "Medication",
            name: "Medication",
            iconName: "pills.fill",
            colorHex: "#EC4899",
            categoryName: "Health",
            description: "Track doses and stay consistent.",
            isRecommended: true
        ),
        SuggestedPreset(
            id: "Water",
            name: "Water",
            iconName: "drop.fill",
            colorHex: "#60A5FA",
            categoryName: "Health",
            description: "Quick hydration check-ins.",
            isRecommended: true
        ),
        SuggestedPreset(
            id: "Exercise",
            name: "Exercise",
            iconName: "figure.run",
            colorHex: "#EC4899",
            categoryName: "Health",
            description: "Workouts, walks, or movement.",
            isRecommended: true
        ),
        SuggestedPreset(
            id: "Sleep",
            name: "Sleep",
            iconName: "bed.double.fill",
            colorHex: "#8B5CF6",
            categoryName: "Health",
            description: "Track nights or naps.",
            isRecommended: false
        ),
        SuggestedPreset(
            id: "Coffee Break",
            name: "Coffee Break",
            iconName: "cup.and.saucer.fill",
            colorHex: "#8B5CF6",
            categoryName: "Personal",
            description: "Keep an eye on caffeine habits.",
            isRecommended: false
        ),
        SuggestedPreset(
            id: "Mood Check-In",
            name: "Mood Check-In",
            iconName: "heart.fill",
            colorHex: "#F43F5E",
            categoryName: "Personal",
            description: "Note how you're feeling.",
            isRecommended: false
        ),
        SuggestedPreset(
            id: "Read",
            name: "Read",
            iconName: "book.fill",
            colorHex: "#14B8A6",
            categoryName: "Personal",
            description: "Log reading sessions.",
            isRecommended: false
        ),
        SuggestedPreset(
            id: "Meal",
            name: "Meal",
            iconName: "fork.knife",
            colorHex: "#F59E0B",
            categoryName: "Life",
            description: "Track meals or nutrition moments.",
            isRecommended: false
        ),
        SuggestedPreset(
            id: "Restaurant",
            name: "Restaurant Visit",
            iconName: "fork.knife.circle.fill",
            colorHex: "#14B8A6",
            categoryName: "Social",
            description: "Remember visits and favorites.",
            isRecommended: false
        )
    ]
}

fileprivate struct SuggestedPreset: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let categoryName: String
    let description: String
    let isRecommended: Bool
}

private struct OnboardingProgressDots: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
            }
        }
        .padding(.bottom, 12)
    }
}

private struct OnboardingTipCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#1a1a2e")!.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct OnboardingHomePreview: View {
    private let previewPresets: [PreviewPreset] = [
        PreviewPreset(name: "Commute", iconName: "car.fill", colorHex: "#6366F1"),
        PreviewPreset(name: "Medication", iconName: "pills.fill", colorHex: "#EC4899"),
        PreviewPreset(name: "Restaurant", iconName: "fork.knife.circle.fill", colorHex: "#14B8A6"),
        PreviewPreset(name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#8B5CF6")
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Example Taps")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(previewPresets) { preset in
                    OnboardingPresetCard(preset: preset)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1a1a2e")!.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct PreviewPreset: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let colorHex: String
}

private struct OnboardingPresetCard: View {
    let preset: PreviewPreset

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: preset.iconName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)

            Text(preset.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: preset.colorHex)!,
                            Color(hex: preset.colorHex)!.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct SuggestedPresetRow: View {
    let preset: SuggestedPreset
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: preset.colorHex)!.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: preset.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: preset.colorHex)!)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(preset.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)

                    Text(preset.categoryName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: preset.colorHex)!)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "#10B981")! : .white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1a1a2e")!.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "#10B981")! : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct OnboardingCategoryChip: View {
    let title: String
    let colorHex: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex)!.opacity(0.25))
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: colorHex)!.opacity(0.6), lineWidth: 1)
                    )
            )
    }
}
