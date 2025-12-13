//
//  EditEventSheet.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

// MARK: - Edit Event Sheet
struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let onSave: (Date, String?) -> Void
    let onDelete: () -> Void
    
    @State private var selectedDate: Date
    @State private var noteText: String
    @State private var showDeleteConfirmation = false
    
    init(event: TrackedEvent, onSave: @escaping (Date, String?) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedDate = State(initialValue: event.timestamp)
        _noteText = State(initialValue: event.notes ?? "")
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
                                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
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
        }
    }
}

// MARK: - Track Confirmation Sheet
struct TrackConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: TrackedEvent
    let onAddNote: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var animateCheckmark = false
    @State private var autoDismissTask: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e")!.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Success Animation
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
                        .scaleEffect(animateCheckmark ? 1.0 : 0.5)
                        .opacity(animateCheckmark ? 1.0 : 0.0)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(animateCheckmark ? 1.0 : 0.3)
                        .opacity(animateCheckmark ? 1.0 : 0.0)
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
                            .foregroundColor(Color(hex: "#60A5FA")!)
                        
                        Text(event.eventName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(event.formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
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
                
                Spacer()
            }
            .padding(.top, 24)
        }
        .onAppear {
            // Trigger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateCheckmark = true
            }
            
            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Auto-dismiss after 5 seconds
            let task = DispatchWorkItem {
                dismiss()
            }
            autoDismissTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
        }
        .onDisappear {
            cancelAutoDismiss()
        }
    }
    
    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
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
                                .fill(Color(hex: "#2a2a4e")!)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: event.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "#60A5FA")!)
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

#Preview {
    EditEventSheet(
        event: TrackedEvent(preset: EventPreset(name: "Test", iconName: "star.fill")),
        onSave: { _, _ in },
        onDelete: { }
    )
}

