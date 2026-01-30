//
//  LocationService.swift
//  glimm
//

import Combine
import CoreLocation

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        locationManager.requestLocation()
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            // Try to get specific place name (e.g., "Starbucks", "Apple Store")
            if let name = placemark.name,
               !name.isEmpty,
               name != placemark.locality,
               name != placemark.thoroughfare,
               !name.contains(placemark.subThoroughfare ?? "!!NO_MATCH!!") {
                // Has a specific place name
                if let locality = placemark.locality {
                    return "\(name), \(locality)"
                }
                return name
            }

            // Fall back to address
            var components: [String] = []

            if let thoroughfare = placemark.thoroughfare {
                if let subThoroughfare = placemark.subThoroughfare {
                    components.append("\(subThoroughfare) \(thoroughfare)")
                } else {
                    components.append(thoroughfare)
                }
            }

            if let locality = placemark.locality {
                components.append(locality)
            }

            if components.isEmpty, let country = placemark.country {
                components.append(country)
            }

            return components.isEmpty ? nil : components.joined(separator: ", ")
        } catch {
            return nil
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently fail - location is optional
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
