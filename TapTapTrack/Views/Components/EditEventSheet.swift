//
//  EditEventSheet.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData
import MapKit

// MARK: - Color Constants
private extension Color {
    static let appBackground = Color(hex: "#1a1a2e")!
    static let cardBackground = Color(hex: "#252540")!
    static let secondaryBackground = Color(hex: "#3a3a5e")!
    static let primaryBlue = Color(hex: "#60A5FA")!
    static let accentPurple = Color(hex: "#667eea")!
}

// MARK: - Edit Event Sheet
struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let onSave: (Date, String?) -> Void
    let onDelete: () -> Void
    
    @StateObject private var locationManager = LocationManager()
    @State private var selectedDate: Date
    @State private var noteText: String
    @State private var showDeleteConfirmation = false
    @State private var locationNameText: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var nearbyBusinesses: [MKMapItem] = []
    @State private var isSearchingBusinesses = false
    @State private var selectedBusiness: MKMapItem?
    @State private var businessSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var numberValue: Double?
    
    var hasLocation: Bool {
        event.latitude != nil && event.longitude != nil
    }
    
    var preset: EventPreset? {
        event.preset
    }
    
    var hasNumberInput: Bool {
        preset?.numberEnabled ?? false
    }
    
    var numberMin: Double? {
        preset?.numberMin
    }
    
    var numberMax: Double? {
        preset?.numberMax
    }
    
    var numberAllowDecimals: Bool {
        preset?.numberAllowDecimals ?? false
    }
    
    private var eventHeaderView: some View {
        VStack(spacing: 8) {
            eventIconCircle
            
            Text(event.eventName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            eventCategoryBadge
        }
    }
    
    private var eventIconCircle: some View {
        ZStack {
            eventIconCircleBackground
            eventIconImage
        }
    }
    
    private var eventIconCircleBackground: some View {
        Circle()
            .fill(eventHeaderGradient)
            .frame(width: 64, height: 64)
    }
    
    private var eventIconImage: some View {
        Image(systemName: event.iconName)
            .font(.system(size: 28))
            .foregroundColor(.white)
    }
    
    private var eventCategoryBadge: some View {
        Text(event.categoryName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondaryBackground)
            .cornerRadius(12)
    }
    
    private var eventHeaderGradient: LinearGradient {
        let startColor = event.color
        let endColor = event.color.opacity(0.7)
        return LinearGradient(
            colors: [startColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    init(event: TrackedEvent, onSave: @escaping (Date, String?) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedDate = State(initialValue: event.timestamp)
        _noteText = State(initialValue: event.notes ?? "")
        _locationNameText = State(initialValue: event.locationName ?? "")
        _latitudeText = State(initialValue: event.latitude != nil ? String(format: "%.6f", event.latitude!) : "")
        _longitudeText = State(initialValue: event.longitude != nil ? String(format: "%.6f", event.longitude!) : "")
        _numberValue = State(initialValue: event.numberValue)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                mainContentScrollView
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.primaryBlue)
                }
            }
            .alert("Delete Event?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                // Search for nearby businesses when editing an event with location
                if hasLocation && nearbyBusinesses.isEmpty {
                    searchNearbyBusinesses()
                }
            }
        }
    }
    
    private var mainContentScrollView: some View {
        ScrollView {
            mainContentVStack
                .padding(.top, 16)
        }
    }
    
    private var mainContentVStack: some View {
        VStack(spacing: 24) {
            // Header
            eventHeaderView
                .padding(.top, 8)
            
            // Notes Section
            notesSection
            
            // Location Section (if location data exists)
            if hasLocation {
                locationSectionView
            }
            
            // Number Input (if enabled for this preset)
            if hasNumberInput {
                numberInputView
            }
            
            // Date Picker Section
            datePickerSection
            
            // Time Picker Section
            timePickerSection
            
            // Action Buttons
            actionButtonsView
            
            Spacer(minLength: 40)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            TextEditor(text: $noteText)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
                .frame(height: 100)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var numberInputView: some View {
        NumberInputSection(
            numberValue: $numberValue,
            min: numberMin,
            max: numberMax,
            allowDecimals: numberAllowDecimals,
            required: preset?.numberRequired ?? false
        )
        .padding(.horizontal)
        .onChange(of: numberValue) { oldValue, newValue in
            event.numberValue = newValue
        }
    }
    
    private var locationSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Location Name - Prominently displayed
            if let locationName = event.locationName, !locationName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.primaryBlue)
                    
                    Text(locationName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 8)
            }
            
            // Embedded Map View
            if let latitude = event.latitude, let longitude = event.longitude {
                mapViewSection(latitude: latitude, longitude: longitude)
            }
            
            // Location Name Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Location Name")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextField("Location name", text: $locationNameText)
                    .textFieldStyle(DarkTextFieldStyle())
            }
            
            // Nearby Businesses
            if event.latitude != nil && event.longitude != nil {
                nearbyBusinessesSection
            }
            
            // Coordinates
            coordinatesSection
            
            // Address (read-only)
            if let address = event.address, !address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(address)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func mapViewSection(latitude: Double, longitude: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Map
            LocationMapView(
                latitude: latitude,
                longitude: longitude,
                locationName: event.locationName ?? "Location"
            )
            .frame(height: 200)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#3a3a5e")!, lineWidth: 1)
            )
            
            // Address - Featured below map
            if let address = event.address, !address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.primaryBlue)
                    
                    Text(address)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(12)
            }
            
            // Open in Maps Button
            Button {
                openInMaps(latitude: latitude, longitude: longitude, name: event.locationName)
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16))
                    Text("Open in Maps")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding()
                .background(mapsButtonGradient)
                .cornerRadius(12)
            }
        }
    }
    
    private var mapsButtonGradient: LinearGradient {
        LinearGradient(
            colors: [Color.primaryBlue, Color(hex: "#3B82F6")!],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var nearbyBusinessesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby Locations")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            // Search field
            businessSearchField
            
            if isSearchingBusinesses {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .padding()
            } else if nearbyBusinesses.isEmpty {
                searchBusinessesButton
            } else {
                businessListScrollView
            }
        }
    }
    
    private var businessSearchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 12)
            
            TextField("Search for a business...", text: $businessSearchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .onChange(of: businessSearchText) { oldValue, newValue in
                    // Debounce search to avoid too many requests
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                        if !Task.isCancelled {
                            await MainActor.run {
                                searchNearbyBusinesses()
                            }
                        }
                    }
                }
            
            if !businessSearchText.isEmpty {
                Button {
                    businessSearchText = ""
                    searchNearbyBusinesses()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 12)
                }
            }
        }
        .background(Color(hex: "#3a3a5e")!)
        .cornerRadius(10)
    }
    
    private var searchBusinessesButton: some View {
        Button {
            searchNearbyBusinesses()
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(businessSearchText.isEmpty ? "Search Nearby Businesses" : "No results found")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "#3a3a5e")!)
            .cornerRadius(12)
        }
    }
    
    private var businessListScrollView: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(nearbyBusinesses.enumerated()), id: \.offset) { index, business in
                    BusinessSelectionCard(
                        business: business,
                        isSelected: isBusinessSelected(business, selectedBusiness: selectedBusiness),
                        onSelect: {
                            selectedBusiness = business
                            locationNameText = business.name ?? ""
                            
                            // Update coordinates to match selected business
                            if let coordinate = business.placemark.location?.coordinate {
                                event.latitude = coordinate.latitude
                                event.longitude = coordinate.longitude
                                latitudeText = String(format: "%.6f", coordinate.latitude)
                                longitudeText = String(format: "%.6f", coordinate.longitude)
                                
                                // Update address by reverse geocoding
                                Task {
                                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                    if let address = try? await locationManager.getAddress(from: location) {
                                        await MainActor.run {
                                            event.address = address
                                        }
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    private var coordinatesSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Latitude")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(DarkTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Longitude")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(DarkTextFieldStyle())
            }
        }
    }
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.accentPurple)
            .colorScheme(.dark)
            .padding()
            .background(Color(hex: "#252540")!)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            DatePicker(
                "Select Time",
                selection: $selectedDate,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "#252540")!)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button("Save Changes") {
                // Update location data if present
                if hasLocation {
                    event.locationName = locationNameText.isEmpty ? nil : locationNameText
                    
                    if let lat = Double(latitudeText) {
                        event.latitude = lat
                    }
                    if let lon = Double(longitudeText) {
                        event.longitude = lon
                    }
                }
                
                // Update number value if present
                event.numberValue = numberValue
                
                onSave(selectedDate, noteText.isEmpty ? nil : noteText)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button("Delete Event") {
                showDeleteConfirmation = true
            }
            .buttonStyle(DestructiveButtonStyle())
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // Open location in iOS Maps app
    private func openInMaps(latitude: Double, longitude: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name ?? "Location"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func searchNearbyBusinesses() {
        guard let lat = event.latitude, let lon = event.longitude else { return }
        
        let location = CLLocation(latitude: lat, longitude: lon)
        let query = businessSearchText.isEmpty ? nil : businessSearchText
        
        Task {
            await MainActor.run {
                isSearchingBusinesses = true
            }
            
            do {
                let businesses = try await locationManager.searchNearbyBusinesses(at: location, query: query)
                await MainActor.run {
                    nearbyBusinesses = businesses
                    isSearchingBusinesses = false
                }
            } catch {
                await MainActor.run {
                    isSearchingBusinesses = false
                }
            }
        }
    }
    
    // Helper function to compare businesses by coordinates (unique identifier)
    private func isBusinessSelected(_ business: MKMapItem, selectedBusiness: MKMapItem?) -> Bool {
        guard let selected = selectedBusiness,
              let businessCoord = business.placemark.location?.coordinate,
              let selectedCoord = selected.placemark.location?.coordinate else {
            return false
        }
        // Compare by coordinates to ensure uniqueness (same name but different location = different business)
        return businessCoord.latitude == selectedCoord.latitude && 
               businessCoord.longitude == selectedCoord.longitude
    }
}

// MARK: - Track Confirmation Sheet
struct TrackConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let isCapturingLocation: Bool
    let onAddNote: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var locationManager = LocationManager()
    @State private var animateCheckmark = false
    @State private var autoDismissTask: DispatchWorkItem?
    @State private var showingLocationEditor = false
    @State private var nearbyBusinesses: [MKMapItem] = []
    @State private var isSearchingBusinesses = false
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?
    @State private var currentIsCapturingLocation: Bool
    @State private var locationMonitoringTask: Task<Void, Never>?
    @State private var numberValue: Double?
    
    init(event: TrackedEvent, isCapturingLocation: Bool, onAddNote: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.isCapturingLocation = isCapturingLocation
        self.onAddNote = onAddNote
        self.onEdit = onEdit
        self.onDelete = onDelete
        _currentIsCapturingLocation = State(initialValue: isCapturingLocation)
        _numberValue = State(initialValue: event.numberValue)
    }
    
    var preset: EventPreset? {
        event.preset
    }
    
    var hasNumberInput: Bool {
        preset?.numberEnabled ?? false
    }
    
    var numberMin: Double? {
        preset?.numberMin
    }
    
    var numberMax: Double? {
        preset?.numberMax
    }
    
    var numberAllowDecimals: Bool {
        preset?.numberAllowDecimals ?? false
    }
    
    var numberRequired: Bool {
        preset?.numberRequired ?? false
    }
    
    var isNumberValid: Bool {
        // If not required, always valid. If required, must have a value.
        !numberRequired || (numberValue != nil)
    }
    
    var hasLocation: Bool {
        event.latitude != nil && event.longitude != nil
    }
    
    var shouldShowLocationLoading: Bool {
        currentIsCapturingLocation && !hasLocation
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Success Animation with Countdown (only show countdown if number is valid)
                    successAnimationView
                    
                    // Event Info
                    VStack(spacing: 8) {
                        Text("Event Tracked!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Image(systemName: event.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(event.color)
                            
                            Text(event.eventName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Text(event.formattedTime)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    // Location Info (if available or capturing)
                    if hasLocation || shouldShowLocationLoading {
                        if shouldShowLocationLoading {
                            // Show loading state while capturing location
                            LocationLoadingSection()
                                .padding(.horizontal)
                        } else {
                            LocationInfoSectionSimple(
                                event: event,
                                onEdit: {
                                    cancelAutoDismiss()
                                    showingLocationEditor = true
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Number Input (if enabled for this preset)
                    if hasNumberInput {
                        NumberInputSection(
                            numberValue: $numberValue,
                            min: numberMin,
                            max: numberMax,
                            allowDecimals: numberAllowDecimals,
                            required: numberRequired
                        )
                        .padding(.horizontal)
                        .onChange(of: numberValue) { oldValue, newValue in
                            event.numberValue = newValue
                            // If number was required and now entered, start countdown
                            if numberRequired && newValue != nil {
                                startCountdown()
                            }
                        }
                    }
                
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            cancelAutoDismiss()
                            onAddNote()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text("Add Note")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button {
                            cancelAutoDismiss()
                            onEdit()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Event")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button {
                            cancelAutoDismiss()
                            onDelete()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                        }
                        .buttonStyle(DestructiveOutlineButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // Done Button
                    Button("Done") {
                        cancelAutoDismiss()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.top, 24)
            }
        }
        .sheet(isPresented: $showingLocationEditor) {
            LocationEditorSheet(
                event: event,
                locationManager: locationManager,
                nearbyBusinesses: $nearbyBusinesses,
                isSearching: $isSearchingBusinesses
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Trigger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateCheckmark = true
            }
            
            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Update capturing state
            currentIsCapturingLocation = isCapturingLocation
            
            // Search for nearby businesses when confirmation sheet appears (if location exists)
            if hasLocation && nearbyBusinesses.isEmpty {
                searchNearbyBusinesses()
            }
            
            // Monitor for location updates - when location is captured, update state and search businesses
            // Store the task so it can be cancelled when the view disappears
            locationMonitoringTask = Task {
                // Add a timeout to prevent infinite loops (max 30 seconds)
                let maxAttempts = 150 // 30 seconds / 0.2 seconds
                var attempts = 0
                
                while currentIsCapturingLocation && !hasLocation && attempts < maxAttempts {
                    // Check for cancellation
                    if Task.isCancelled {
                        break
                    }
                    
                    try? await Task.sleep(nanoseconds: 200_000_000) // Check every 0.2 seconds
                    attempts += 1
                    
                    // SwiftData will automatically update the view when event.latitude changes
                    // This task just updates our local state and triggers business search
                    if hasLocation {
                        await MainActor.run {
                            currentIsCapturingLocation = false
                            if nearbyBusinesses.isEmpty {
                                searchNearbyBusinesses()
                            }
                        }
                        break
                    }
                }
                
                // If we exit the loop without location, stop monitoring
                await MainActor.run {
                    currentIsCapturingLocation = false
                }
            }
            
            // Start countdown only if number is not required or number is already entered
            if isNumberValid {
                startCountdown()
            }
        }
        .onDisappear {
            cancelAutoDismiss()
            countdownTimer?.invalidate()
            countdownTimer = nil
            // Cancel location monitoring task to prevent resource leaks
            locationMonitoringTask?.cancel()
            locationMonitoringTask = nil
        }
    }
    
    private func startCountdown() {
        // Cancel any existing countdown
        cancelAutoDismiss()
        
        // Start countdown timer
        countdown = 5
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                countdownTimer = nil
            }
        }
        
        // Auto-dismiss after 5 seconds
        let task = DispatchWorkItem {
            dismiss()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }
    
    private var successAnimationView: some View {
        ZStack {
            // Countdown circle (outer ring) - only show if countdown is active
            if isNumberValid {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: max(0, min(1, CGFloat(countdown) / 5.0)))
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#10B981")!, Color(hex: "#059669")!],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: countdown)
            }
            
                        // Success checkmark circle with countdown number inside
                        checkmarkCircleView
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateCheckmark)
    }
    
    private var countdownProgress: CGFloat {
        max(0, min(1, CGFloat(countdown) / 5.0))
    }
    
    private var countdownGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#10B981")!, Color(hex: "#059669")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var countdownStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 4, lineCap: .round)
    }
    
    private var checkmarkCircleView: some View {
        ZStack {
            Circle()
                .fill(checkmarkGradient)
                .frame(width: 80, height: 80)
            
            // Show countdown number while counting, checkmark when done
            checkmarkContent
        }
        .scaleEffect(checkmarkScale)
        .opacity(checkmarkOpacity)
    }
    
    private var checkmarkContent: some View {
        Group {
            if isNumberValid && countdown > 0 {
                Text("\(countdown)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.3)
                    .opacity(animateCheckmark ? 1.0 : 0.0)
            }
        }
    }
    
    private var checkmarkScale: CGFloat {
        isNumberValid && countdown > 0 ? 1.0 : (animateCheckmark ? 1.0 : 0.5)
    }
    
    private var checkmarkGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#10B981")!, Color(hex: "#059669")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var checkmarkOpacity: Double {
        isNumberValid && countdown > 0 ? 1.0 : (animateCheckmark ? 1.0 : 0.0)
    }
    
    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func searchNearbyBusinesses() {
        guard let lat = event.latitude, let lon = event.longitude else { return }
        
        let location = CLLocation(latitude: lat, longitude: lon)
        
        Task {
            await MainActor.run {
                isSearchingBusinesses = true
            }
            
            do {
                let businesses = try await locationManager.searchNearbyBusinesses(at: location)
                await MainActor.run {
                    nearbyBusinesses = businesses
                    isSearchingBusinesses = false
                }
            } catch {
                await MainActor.run {
                    isSearchingBusinesses = false
                }
            }
        }
    }
}

// MARK: - Quick Note Sheet
struct QuickNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let onSave: (String?) -> Void
    
    @State private var noteText: String
    
    init(event: TrackedEvent, onSave: @escaping (String?) -> Void) {
        self.event = event
        self.onSave = onSave
        _noteText = State(initialValue: event.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Event Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(event.color.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: event.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(event.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.eventName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(event.formattedTime)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Note Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $noteText)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.white)
                            .frame(height: 120)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // Save Button
                    Button("Save Note") {
                        onSave(noteText.isEmpty ? nil : noteText)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.primaryBlue)
                }
            }
        }
    }
}

// MARK: - Button Styles
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#DC2626")!)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct DestructiveOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "#EF4444")!)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#EF4444")!, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Location Info Section (Simple - for confirmation screen)
struct LocationInfoSectionSimple: View {
    let event: TrackedEvent
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.primaryBlue)
                
                Text("Location")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            
            // Location Name - Prominently displayed
            if let locationName = event.locationName, !locationName.isEmpty {
                Text(locationName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("Custom Location")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // Address - Prominently displayed
            if let address = event.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(address)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
    }
}

// MARK: - Location Info Section (Full - for edit screen with map)
struct LocationInfoSection: View {
    let event: TrackedEvent
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.primaryBlue)
                
                Text("Location")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            
            // Location Name - Prominently displayed
            if let locationName = event.locationName, !locationName.isEmpty {
                Text(locationName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("Custom Location")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // Address - Prominently displayed
            if let address = event.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(address)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Embedded Map View (if coordinates available)
            if let latitude = event.latitude, let longitude = event.longitude {
                LocationMapView(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: event.locationName ?? "Location"
                )
                .frame(height: 180)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#3a3a5e")!, lineWidth: 1)
                )
                
                // Open in Maps Button
                Button {
                    openInMaps(latitude: latitude, longitude: longitude, name: event.locationName)
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16))
                        Text("Open in Maps")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA")!, Color(hex: "#3B82F6")!],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
    }
    
    // Open location in iOS Maps app
    private func openInMaps(latitude: Double, longitude: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name ?? "Location"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Location Loading Section
struct LocationLoadingSection: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.primaryBlue)
                
                Text("Location")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#60A5FA")!))
                    .scaleEffect(0.8)
                
                Text("Finding your location...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
    }
}

// MARK: - Location Editor Sheet
struct LocationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let locationManager: LocationManager
    @Binding var nearbyBusinesses: [MKMapItem]
    @Binding var isSearching: Bool
    
    @State private var customLocationName: String
    @State private var selectedBusiness: MKMapItem?
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    init(event: TrackedEvent, locationManager: LocationManager, nearbyBusinesses: Binding<[MKMapItem]>, isSearching: Binding<Bool>) {
        self.event = event
        self.locationManager = locationManager
        _nearbyBusinesses = nearbyBusinesses
        _isSearching = isSearching
        _customLocationName = State(initialValue: event.locationName ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Custom Name Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField("Enter location name", text: $customLocationName)
                                .textFieldStyle(DarkTextFieldStyle())
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Nearby Businesses
                        if event.latitude != nil && event.longitude != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nearby Locations")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                
                                // Search field
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 12)
                                    
                                    TextField("Search for a business...", text: $searchText)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .onChange(of: searchText) { oldValue, newValue in
                                            // Debounce search to avoid too many requests
                                            searchTask?.cancel()
                                            searchTask = Task {
                                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                                if !Task.isCancelled {
                                                    await MainActor.run {
                                                        searchNearbyBusinesses()
                                                    }
                                                }
                                            }
                                        }
                                    
                                    if !searchText.isEmpty {
                                        Button {
                                            searchText = ""
                                            searchNearbyBusinesses()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 12)
                                        }
                                    }
                                }
                                .background(Color.secondaryBackground)
                                .cornerRadius(10)
                                
                                if isSearching {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(.white)
                                        Spacer()
                                    }
                                    .padding()
                                } else if nearbyBusinesses.isEmpty {
                                    Button {
                                        searchNearbyBusinesses()
                                    } label: {
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                            Text(searchText.isEmpty ? "Search Nearby Businesses" : "No results found")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.secondaryBackground)
                                        .cornerRadius(12)
                                    }
                                } else {
                                    ScrollView {
                                        VStack(spacing: 8) {
                                            ForEach(Array(nearbyBusinesses.enumerated()), id: \.offset) { index, business in
                                                BusinessSelectionCard(
                                                    business: business,
                                                    isSelected: isBusinessSelected(business, selectedBusiness: selectedBusiness),
                                                    onSelect: {
                                                        selectedBusiness = business
                                                        customLocationName = business.name ?? ""
                                                        
                                                        // Update coordinates to match selected business
                                                        if let coordinate = business.placemark.location?.coordinate {
                                                            event.latitude = coordinate.latitude
                                                            event.longitude = coordinate.longitude
                                                            
                                                            // Update address by reverse geocoding
                                                            Task {
                                                                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                                                if let address = try? await locationManager.getAddress(from: location) {
                                                                    await MainActor.run {
                                                                        event.address = address
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Coordinates (read-only display)
                        if let lat = event.latitude, let lon = event.longitude {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Coordinates")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Latitude")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.6f", lat))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Longitude")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.6f", lon))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Save Button
                        Button("Save") {
                            event.locationName = customLocationName.isEmpty ? nil : customLocationName
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.primaryBlue)
                }
            }
        }
        .onAppear {
            if nearbyBusinesses.isEmpty && event.latitude != nil && event.longitude != nil {
                searchNearbyBusinesses()
            }
        }
    }
    
    private func searchNearbyBusinesses() {
        guard let latitude = event.latitude, let longitude = event.longitude else { return }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let query = searchText.isEmpty ? nil : searchText
        
        Task {
            await MainActor.run {
                isSearching = true
            }
            
            do {
                let businesses = try await locationManager.searchNearbyBusinesses(at: location, query: query)
                await MainActor.run {
                    nearbyBusinesses = businesses
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
    
    // Helper function to compare businesses by coordinates (unique identifier)
    private func isBusinessSelected(_ business: MKMapItem, selectedBusiness: MKMapItem?) -> Bool {
        guard let selected = selectedBusiness,
              let businessCoord = business.placemark.location?.coordinate,
              let selectedCoord = selected.placemark.location?.coordinate else {
            return false
        }
        // Compare by coordinates to ensure uniqueness (same name but different location = different business)
        return businessCoord.latitude == selectedCoord.latitude && 
               businessCoord.longitude == selectedCoord.longitude
    }
}

// MARK: - Business Selection Card
struct BusinessSelectionCard: View {
    let business: MKMapItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#667eea")! : Color(hex: "#3a3a5e")!)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isSelected ? "checkmark" : "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.name ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let address = business.placemark.title {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#252540")!)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "#667eea")! : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Location Map View
struct LocationMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let locationName: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isUserInteractionEnabled = false
        
        // Create annotation for the location
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = locationName
        mapView.addAnnotation(annotation)
        
        // Set region to show the location
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            
            let identifier = "LocationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor.systemBlue
                markerView.glyphImage = UIImage(systemName: "mappin.circle.fill")
            }
            
            return annotationView
        }
    }
}

// MARK: - Number Input Section
struct NumberInputSection: View {
    @Binding var numberValue: Double?
    let min: Double?
    let max: Double?
    let allowDecimals: Bool
    let required: Bool
    
    @State private var textValue: String = ""
    @State private var isEditing = false
    
    private var hasRange: Bool {
        min != nil && max != nil
    }
    
    private var currentValue: Double {
        guard let min = min, let max = max else {
            // If no range, return current value or midpoint
            return numberValue ?? ((min ?? 0) + (max ?? 100)) / 2
        }
        if let value = numberValue {
            let clamped = Swift.max(min, Swift.min(max, value))
            // Round to integer if decimals not allowed
            return allowDecimals ? clamped : round(clamped)
        }
        // Default to midpoint of range for slider
        let defaultValue = (min + max) / 2
        return allowDecimals ? defaultValue : round(defaultValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundColor(Color.primaryBlue)
                
                Text("Number")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if required && numberValue == nil {
                    Text("Required")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#FBBF24")!)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FBBF24")!.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Slider and input on same line (only show slider if min and max are both set)
            if hasRange, let min = min, let max = max {
                VStack(spacing: 8) {
                    // Slider and input on same line
                    HStack(spacing: 12) {
                        // Slider
                        Slider(
                            value: Binding(
                                get: { 
                                    // Return current value if set, otherwise midpoint for slider display
                                    if let value = numberValue {
                                        let clamped = Swift.max(min, Swift.min(max, value))
                                        return allowDecimals ? clamped : round(clamped)
                                    }
                                    // Use midpoint for slider position, but don't set numberValue
                                    let midpoint = (min + max) / 2
                                    return allowDecimals ? midpoint : round(midpoint)
                                },
                                set: { newValue in
                                    let finalValue = allowDecimals ? newValue : round(newValue)
                                    numberValue = finalValue
                                    textValue = formatValue(finalValue)
                                }
                            ),
                            in: min...max,
                            step: allowDecimals ? calculateStep() : 1.0
                        )
                        .tint(Color.accentPurple)
                        
                        // Direct input field (to the right of slider)
                        TextField("Value", text: $textValue)
                            .keyboardType(allowDecimals ? .decimalPad : .numberPad)
                            .textFieldStyle(DarkTextFieldStyle())
                            .frame(width: 80)
                            .onChange(of: textValue) { oldValue, newValue in
                                if let value = Double(newValue) {
                                    let clampedValue = Swift.max(min, Swift.min(max, value))
                                    let finalValue = allowDecimals ? clampedValue : round(clampedValue)
                                    numberValue = finalValue
                                    if finalValue != value {
                                        textValue = formatValue(finalValue)
                                    }
                                } else if newValue.isEmpty {
                                    numberValue = nil
                                }
                            }
                            .onAppear {
                                // Only show existing value, don't set default
                                if let value = numberValue {
                                    textValue = formatValue(value)
                                }
                            }
                    }
                    
                    // Min and Max labels
                    HStack {
                        Text(formatValue(min))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(formatValue(max))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // No range - just show input field
                HStack(spacing: 12) {
                    Text("Value:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextField("Enter number", text: $textValue)
                        .keyboardType(allowDecimals ? .decimalPad : .numberPad)
                        .textFieldStyle(DarkTextFieldStyle())
                        .onChange(of: textValue) { oldValue, newValue in
                            if let value = Double(newValue) {
                                // No range restriction, just round if decimals not allowed
                                let finalValue = allowDecimals ? value : round(value)
                                numberValue = finalValue
                                if finalValue != value {
                                    textValue = formatValue(finalValue)
                                }
                            } else if newValue.isEmpty {
                                numberValue = nil
                            }
                        }
                        .onAppear {
                            // Only show existing value, don't set default
                            if let value = numberValue {
                                textValue = formatValue(value)
                            }
                        }
                }
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
    }
    
    private func formatValue(_ value: Double) -> String {
        if allowDecimals {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            } else {
                return String(format: "%.2f", value)
            }
        } else {
            return String(format: "%.0f", round(value))
        }
    }
    
    private func calculateStep() -> Double {
        guard let min = min, let max = max else {
            return 1.0
        }
        let range = max - min
        if range <= 10 {
            return 0.1
        } else if range <= 100 {
            return 1.0
        } else if range <= 1000 {
            return 10.0
        } else {
            return 100.0
        }
    }
}

#Preview {
    EditEventSheet(
        event: TrackedEvent(preset: EventPreset(name: "Test", iconName: "star.fill")),
        onSave: { _, _ in },
        onDelete: { }
    )
}

