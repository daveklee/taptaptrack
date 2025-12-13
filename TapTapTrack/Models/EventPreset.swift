//
//  EventPreset.swift
//  Tap Tap Track
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class EventPreset {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String?
    var createdAt: Date
    
    var category: Category?
    
    @Relationship(deleteRule: .cascade, inverse: \TrackedEvent.preset)
    var trackedEvents: [TrackedEvent]?
    
    init(name: String, iconName: String = "star.fill", colorHex: String = "#667eea", category: Category? = nil) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.category = category
    }
    
    var color: Color {
        if let colorHex = colorHex, !colorHex.isEmpty, let color = Color(hex: colorHex) {
            return color
        }
        // Fallback for existing presets without colorHex
        return Color(hex: "#667eea") ?? .purple
    }
}

// MARK: - Available Icons
extension EventPreset {
    
    // Icon categories for organized display
    static let iconCategories: [(category: String, icons: [(name: String, systemName: String)])] = [
        ("Health & Fitness", [
            ("Exercise", "figure.run"),
            ("Strength", "figure.strengthtraining.traditional"),
            ("Yoga", "figure.yoga"),
            ("Cycling", "figure.outdoor.cycle"),
            ("Swimming", "figure.pool.swim"),
            ("Walking", "figure.walk"),
            ("Hiking", "figure.hiking"),
            ("Dance", "figure.dance"),
            ("Meditation", "brain.head.profile"),
            ("Sleep", "bed.double.fill"),
            ("Heart", "heart.fill"),
            ("Heartbeat", "waveform.path.ecg"),
            ("Medical", "cross.fill"),
            ("Pill", "pills.fill"),
            ("Bandage", "bandage.fill"),
            ("Lungs", "lungs.fill"),
            ("Weight", "scalemass.fill"),
        ]),
        ("Food & Drink", [
            ("Food", "fork.knife"),
            ("Coffee", "cup.and.saucer.fill"),
            ("Water", "drop.fill"),
            ("Wine", "wineglass.fill"),
            ("Beer", "mug.fill"),
            ("Takeout", "takeoutbag.and.cup.and.straw.fill"),
            ("Birthday", "birthday.cake.fill"),
            ("Carrot", "carrot.fill"),
            ("Leaf", "leaf.fill"),
        ]),
        ("Work & Productivity", [
            ("Work", "briefcase.fill"),
            ("Laptop", "laptopcomputer"),
            ("Desktop", "desktopcomputer"),
            ("Meeting", "person.3.fill"),
            ("Video Call", "video.fill"),
            ("Phone", "phone.fill"),
            ("Email", "envelope.fill"),
            ("Document", "doc.fill"),
            ("Folder", "folder.fill"),
            ("Calendar", "calendar"),
            ("Clock", "clock.fill"),
            ("Alarm", "alarm.fill"),
            ("Check", "checkmark.circle.fill"),
            ("Target", "target"),
            ("Chart", "chart.bar.fill"),
            ("Lightbulb", "lightbulb.fill"),
            ("Pencil", "pencil"),
            ("Scissors", "scissors"),
        ]),
        ("Social & Communication", [
            ("Person", "person.fill"),
            ("People", "person.2.fill"),
            ("Group", "person.3.fill"),
            ("Message", "message.fill"),
            ("Chat", "bubble.left.fill"),
            ("Phone Call", "phone.arrow.up.right.fill"),
            ("FaceTime", "video.fill"),
            ("Share", "square.and.arrow.up.fill"),
            ("Hand Wave", "hand.wave.fill"),
            ("Handshake", "hands.clap.fill"),
            ("Heart Hands", "heart.circle.fill"),
            ("Party", "party.popper.fill"),
        ]),
        ("Home & Life", [
            ("Home", "house.fill"),
            ("Bed", "bed.double.fill"),
            ("Bath", "bathtub.fill"),
            ("Shower", "shower.fill"),
            ("Laundry", "washer.fill"),
            ("Cleaning", "bubbles.and.sparkles.fill"),
            ("Cooking", "frying.pan.fill"),
            ("Pet", "pawprint.fill"),
            ("Plant", "leaf.fill"),
            ("Garden", "tree.fill"),
            ("Key", "key.fill"),
            ("Lock", "lock.fill"),
            ("Light", "lightbulb.fill"),
            ("Trash", "trash.fill"),
        ]),
        ("Travel & Transport", [
            ("Car", "car.fill"),
            ("Bus", "bus.fill"),
            ("Train", "tram.fill"),
            ("Airplane", "airplane"),
            ("Bicycle", "bicycle"),
            ("Scooter", "scooter"),
            ("Walk", "figure.walk"),
            ("Map", "map.fill"),
            ("Location", "location.fill"),
            ("Compass", "safari.fill"),
            ("Fuel", "fuelpump.fill"),
            ("Parking", "parkingsign"),
            ("Suitcase", "suitcase.fill"),
            ("Ticket", "ticket.fill"),
        ]),
        ("Entertainment & Hobbies", [
            ("Music", "music.note"),
            ("Headphones", "headphones"),
            ("Microphone", "mic.fill"),
            ("Guitar", "guitars.fill"),
            ("Piano", "pianokeys"),
            ("Movie", "film.fill"),
            ("TV", "tv.fill"),
            ("Game", "gamecontroller.fill"),
            ("Dice", "dice.fill"),
            ("Puzzle", "puzzlepiece.fill"),
            ("Book", "book.fill"),
            ("Magazine", "magazine.fill"),
            ("Photo", "camera.fill"),
            ("Video", "video.fill"),
            ("Art", "paintbrush.fill"),
            ("Palette", "paintpalette.fill"),
            ("Ticket", "ticket.fill"),
            ("Theater", "theatermasks.fill"),
        ]),
        ("Shopping & Money", [
            ("Shopping", "bag.fill"),
            ("Cart", "cart.fill"),
            ("Gift", "gift.fill"),
            ("Credit Card", "creditcard.fill"),
            ("Money", "dollarsign.circle.fill"),
            ("Wallet", "wallet.pass.fill"),
            ("Tag", "tag.fill"),
            ("Barcode", "barcode"),
            ("Receipt", "receipt.fill"),
            ("Store", "storefront.fill"),
        ]),
        ("Nature & Weather", [
            ("Sun", "sun.max.fill"),
            ("Moon", "moon.fill"),
            ("Star", "star.fill"),
            ("Cloud", "cloud.fill"),
            ("Rain", "cloud.rain.fill"),
            ("Snow", "cloud.snow.fill"),
            ("Thunder", "cloud.bolt.fill"),
            ("Wind", "wind"),
            ("Thermometer", "thermometer.medium"),
            ("Umbrella", "umbrella.fill"),
            ("Sunrise", "sunrise.fill"),
            ("Sunset", "sunset.fill"),
            ("Rainbow", "rainbow"),
            ("Flame", "flame.fill"),
            ("Drop", "drop.fill"),
            ("Snowflake", "snowflake"),
            ("Leaf", "leaf.fill"),
            ("Tree", "tree.fill"),
            ("Mountain", "mountain.2.fill"),
            ("Wave", "water.waves"),
        ]),
        ("Education & Learning", [
            ("Book", "book.fill"),
            ("Books", "books.vertical.fill"),
            ("Backpack", "backpack.fill"),
            ("Graduation", "graduationcap.fill"),
            ("Pencil", "pencil"),
            ("Ruler", "ruler.fill"),
            ("Globe", "globe.americas.fill"),
            ("Atom", "atom"),
            ("Function", "function"),
            ("Brain", "brain.head.profile"),
            ("Lightbulb", "lightbulb.fill"),
            ("Magnifier", "magnifyingglass"),
        ]),
        ("Tech & Devices", [
            ("iPhone", "iphone"),
            ("iPad", "ipad"),
            ("Mac", "laptopcomputer"),
            ("Watch", "applewatch"),
            ("AirPods", "airpodspro"),
            ("TV", "appletv.fill"),
            ("Speaker", "hifispeaker.fill"),
            ("Keyboard", "keyboard.fill"),
            ("Mouse", "computermouse.fill"),
            ("Printer", "printer.fill"),
            ("WiFi", "wifi"),
            ("Bluetooth", "wave.3.right"),
            ("Battery", "battery.100"),
            ("Bolt", "bolt.fill"),
            ("Server", "server.rack"),
            ("QR Code", "qrcode"),
        ]),
        ("Symbols & Shapes", [
            ("Star", "star.fill"),
            ("Heart", "heart.fill"),
            ("Circle", "circle.fill"),
            ("Square", "square.fill"),
            ("Triangle", "triangle.fill"),
            ("Diamond", "diamond.fill"),
            ("Hexagon", "hexagon.fill"),
            ("Checkmark", "checkmark.circle.fill"),
            ("Plus", "plus.circle.fill"),
            ("Minus", "minus.circle.fill"),
            ("X Mark", "xmark.circle.fill"),
            ("Info", "info.circle.fill"),
            ("Question", "questionmark.circle.fill"),
            ("Exclamation", "exclamationmark.circle.fill"),
            ("Bell", "bell.fill"),
            ("Flag", "flag.fill"),
            ("Pin", "pin.fill"),
            ("Bookmark", "bookmark.fill"),
            ("Tag", "tag.fill"),
            ("Crown", "crown.fill"),
            ("Sparkle", "sparkle"),
            ("Sparkles", "sparkles"),
        ]),
    ]
    
    // Flat list of all icons for backward compatibility
    static var availableIcons: [(name: String, systemName: String)] {
        iconCategories.flatMap { $0.icons }
    }
}

