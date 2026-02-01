//
//  LocationPickerView.swift
//  glimm
//

import Combine
import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @StateObject private var locationService = LocationService()

    @Binding var selectedLocationName: String?
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?

    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMapLocation: CLLocationCoordinate2D?
    @State private var isReverseGeocoding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Mode", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("Map").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    searchView
                } else {
                    mapView
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == 1 && selectedMapLocation != nil {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                setupInitialPosition()
            }
        }
    }

    // MARK: - Search View

    private var searchView: some View {
        List {
            // Current/Selected location
            if let name = selectedLocationName {
                Section {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        Text(name)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Selected")
                }
            }

            // Search results
            if !searchCompleter.results.isEmpty {
                Section {
                    ForEach(searchCompleter.results, id: \.self) { result in
                        Button {
                            selectSearchResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Search Results")
                }
            }

            // Remove location option
            if selectedLocationName != nil {
                Section {
                    Button(role: .destructive) {
                        selectedLocationName = nil
                        selectedLatitude = nil
                        selectedLongitude = nil
                        selectedMapLocation = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "location.slash")
                            Text("Remove Location")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search location")
        .onChange(of: searchText) { _, newValue in
            searchCompleter.search(query: newValue)
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coord = selectedMapLocation {
                        Marker("", coordinate: coord)
                            .tint(.red)
                    }
                }
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        selectMapLocation(coordinate)
                    }
                }
            }

            // Location info overlay
            VStack {
                Spacer()

                if isReverseGeocoding {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Finding location...")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                } else if let name = selectedLocationName {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                            Text(name)
                                .font(.subheadline)
                            Spacer()
                        }

                        Text("Tap anywhere on the map to change location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                } else {
                    Text("Tap on the map to select a location")
                        .font(.subheadline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }

            // Current location button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        moveToCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.body)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    // MARK: - Functions

    private func setupInitialPosition() {
        if let lat = selectedLatitude, let lon = selectedLongitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedMapLocation = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        } else {
            locationService.requestLocation()
            // Default to user's location or a default region
            if let location = locationService.currentLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                ))
            }
        }
    }

    private func moveToCurrentLocation() {
        locationService.requestLocation()

        Task {
            // Wait a bit for location
            try? await Task.sleep(for: .milliseconds(500))

            if let location = locationService.currentLocation {
                await MainActor.run {
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: location.coordinate,
                            latitudinalMeters: 500,
                            longitudinalMeters: 500
                        ))
                    }
                    selectMapLocation(location.coordinate)
                }
            }
        }
    }

    private func selectMapLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedMapLocation = coordinate
        selectedLatitude = coordinate.latitude
        selectedLongitude = coordinate.longitude
        isReverseGeocoding = true

        Task {
            if let name = await locationService.reverseGeocode(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) {
                await MainActor.run {
                    selectedLocationName = name
                    isReverseGeocoding = false
                }
            } else {
                await MainActor.run {
                    selectedLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                    isReverseGeocoding = false
                }
            }
        }
    }

    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()
                if let item = response.mapItems.first {
                    await MainActor.run {
                        let placemark = item.placemark

                        var name = completion.title
                        if let locality = placemark.locality,
                           !completion.title.contains(locality) {
                            name = "\(completion.title), \(locality)"
                        }

                        selectedLocationName = name
                        selectedLatitude = placemark.coordinate.latitude
                        selectedLongitude = placemark.coordinate.longitude
                        selectedMapLocation = placemark.coordinate
                        dismiss()
                    }
                }
            } catch {
                dismiss()
            }
        }
    }
}

// MARK: - Location Search Completer

@MainActor
class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func search(query: String) {
        if query.isEmpty {
            results = []
        } else {
            completer.queryFragment = query
        }
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}

#Preview {
    LocationPickerView(
        selectedLocationName: .constant("Starbucks, Seoul"),
        selectedLatitude: .constant(37.5665),
        selectedLongitude: .constant(126.9780)
    )
}
