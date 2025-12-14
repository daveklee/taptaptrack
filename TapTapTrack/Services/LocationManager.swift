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
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        if let query = query, !query.isEmpty {
            request.naturalLanguageQuery = query
        } else {
            // Search for nearby businesses using a general query
            request.naturalLanguageQuery = "business"
        }
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
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
