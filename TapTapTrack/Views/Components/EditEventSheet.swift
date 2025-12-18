//
//  EditEventSheet.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData
import MapKit

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
    
    var hasLocation: Bool {
        event.latitude != nil && event.longitude != nil
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
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [event.color, event.color.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: event.iconName)
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            
                            Text(event.eventName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(event.categoryName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#3a3a5e")!)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                        
                        // Notes Section (at the top for quick access)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextEditor(text: $noteText)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .frame(height: 100)
                                .padding()
                                .background(Color(hex: "#252540")!)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // Location Section (if location data exists) - moved to top
                        if hasLocation {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Location")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                // Location Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Location Name")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    TextField("Location name", text: $locationNameText)
                                        .textFieldStyle(DarkTextFieldStyle())
                                }
                                
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
                                        
                                        if isSearchingBusinesses {
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
                                                    Text(businessSearchText.isEmpty ? "Search Nearby Businesses" : "No results found")
                                                }
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color(hex: "#3a3a5e")!)
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
                                    }
                                }
                                
                                // Coordinates
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
                        
                        // Date Picker Section
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
                            .tint(Color(hex: "#667eea")!)
                            .colorScheme(.dark)
                            .padding()
                            .background(Color(hex: "#252540")!)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // Time Picker Section
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
                        
                        // Action Buttons
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
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#60A5FA")!)
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
    @State private var countdown: Int = 5
    @State private var countdownTimer: Timer?
    @State private var currentIsCapturingLocation: Bool
    @State private var locationMonitoringTask: Task<Void, Never>?
    
    init(event: TrackedEvent, isCapturingLocation: Bool, onAddNote: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.isCapturingLocation = isCapturingLocation
        self.onAddNote = onAddNote
        self.onEdit = onEdit
        self.onDelete = onDelete
        _currentIsCapturingLocation = State(initialValue: isCapturingLocation)
    }
    
    var hasLocation: Bool {
        event.latitude != nil && event.longitude != nil
    }
    
    var shouldShowLocationLoading: Bool {
        currentIsCapturingLocation && !hasLocation
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e")!.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Success Animation with Countdown
                    ZStack {
                        // Countdown circle (outer ring)
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
                        
                        // Success checkmark circle with countdown number inside
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#10B981")!, Color(hex: "#059669")!],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            // Show countdown number while counting, checkmark when done
                            if countdown > 0 {
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
                        .scaleEffect(countdown > 0 ? 1.0 : (animateCheckmark ? 1.0 : 0.5))
                        .opacity(countdown > 0 ? 1.0 : (animateCheckmark ? 1.0 : 0.0))
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateCheckmark)
                    
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
                            LocationInfoSection(
                                event: event,
                                onEdit: {
                                    cancelAutoDismiss()
                                    showingLocationEditor = true
                                }
                            )
                            .padding(.horizontal)
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
                                Image(systemName: "note.text")
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
        .onDisappear {
            cancelAutoDismiss()
            countdownTimer?.invalidate()
            countdownTimer = nil
            // Cancel location monitoring task to prevent resource leaks
            locationMonitoringTask?.cancel()
            locationMonitoringTask = nil
        }
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
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
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
                    .background(Color(hex: "#252540")!)
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
                            .background(Color(hex: "#252540")!)
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
                    .foregroundColor(Color(hex: "#60A5FA")!)
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

// MARK: - Location Info Section
struct LocationInfoSection: View {
    let event: TrackedEvent
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#60A5FA")!)
                
                Text("Location")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#60A5FA")!)
                }
            }
            
            if let locationName = event.locationName, !locationName.isEmpty {
                Text(locationName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("Custom Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            if let address = event.address, !address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(address)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
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
                    .foregroundColor(Color(hex: "#60A5FA")!)
                
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
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
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
                                .background(Color(hex: "#3a3a5e")!)
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
                                        .background(Color(hex: "#3a3a5e")!)
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
                                .background(Color(hex: "#252540")!)
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
                    .foregroundColor(Color(hex: "#60A5FA")!)
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

#Preview {
    EditEventSheet(
        event: TrackedEvent(preset: EventPreset(name: "Test", iconName: "star.fill")),
        onSave: { _, _ in },
        onDelete: { }
    )
}

