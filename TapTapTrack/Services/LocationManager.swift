//
//  LocationManager.swift
//  Tap Tap Track
//
//  Location services for tracking events with location data

import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocating = false
    @Published var locationError: Error?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        isLocating = true
        locationError = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.locationContinuation = continuation
                self.locationManager.requestLocation()
            }
        }
    }
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    func searchNearbyBusinesses(at location: CLLocation, query: String? = nil) async throws -> [MKMapItem] {
        // If there's a specific query, use MKLocalSearch
        if let query = query, !query.isEmpty {
            let request = MKLocalSearch.Request()
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            request.naturalLanguageQuery = query
            
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            // Filter and sort by distance
            let validItems = response.mapItems.filter { $0.name != nil && !$0.name!.isEmpty }
            let sortedItems = validItems.sorted { item1, item2 in
                guard let location1 = item1.placemark.location,
                      let location2 = item2.placemark.location else {
                    return false
                }
                let distance1 = location.distance(from: location1)
                let distance2 = location.distance(from: location2)
                return distance1 < distance2
            }
            return Array(sortedItems.prefix(20))
        } else {
            // For general nearby search, use MKLocalPointsOfInterestRequest
            // This gives us actual points of interest sorted by distance
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            
            // Focus on restaurants, bars, and entertainment venues
            if #available(iOS 13.4, *) {
                let categories: [MKPointOfInterestCategory] = [
                    .restaurant,      // Restaurants
                    .cafe,            // Cafes
                    .nightlife,       // Bars, clubs, nightlife
                    .brewery,         // Breweries
                    .winery,          // Wineries
                    .theater,         // Movie theaters and theaters
                    .amusementPark,   // Arcades, amusement parks
                    .stadium,         // Sports/entertainment venues
                    .museum           // Museums (entertainment)
                ]
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
            }
            
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            // Filter out items without names and sort by distance
            let validItems = response.mapItems.filter { item in
                guard let name = item.name, !name.isEmpty else { return false }
                // Filter out generic or unhelpful names
                let lowerName = name.lowercased()
                return !lowerName.contains("parking") && 
                       !lowerName.contains("lot") &&
                       name.count > 2
            }
            
            let sortedItems = validItems.sorted { item1, item2 in
                guard let location1 = item1.placemark.location,
                      let location2 = item2.placemark.location else {
                    return false
                }
                let distance1 = location.distance(from: location1)
                let distance2 = location.distance(from: location2)
                return distance1 < distance2
            }
            
            // Return up to 20 closest results
            return Array(sortedItems.prefix(20))
        }
    }
    
    func reverseGeocode(location: CLLocation) async throws -> String? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first?.name
    }
    
    func getAddress(from location: CLLocation) async throws -> String? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }
        
        var addressComponents: [String] = []
        if let street = placemark.thoroughfare {
            addressComponents.append(street)
        }
        if let city = placemark.locality {
            addressComponents.append(city)
        }
        if let state = placemark.administrativeArea {
            addressComponents.append(state)
        }
        if let zip = placemark.postalCode {
            addressComponents.append(zip)
        }
        
        return addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                self.currentLocation = location
                self.isLocating = false
                self.locationError = nil
                
                let continuation = self.locationContinuation
                self.locationContinuation = nil
                continuation?.resume(returning: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
            self.locationError = error
            
            let continuation = self.locationContinuation
            self.locationContinuation = nil
            continuation?.resume(throwing: error)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to track events with location data."
        case .locationUnavailable:
            return "Unable to determine your current location."
        case .unknown:
            return "An unknown error occurred while getting your location."
        }
    }
}




