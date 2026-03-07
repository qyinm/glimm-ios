//
//  ClusteredPlacesMapView.swift
//  glimm
//

import SwiftUI
import MapKit

struct ClusteredPlacesMapView: UIViewRepresentable {
    let places: [PlaceMemoryGroup]
    @Binding var selectedPlace: PlaceMemoryGroup?
    var onClusterSelect: ([PlaceMemoryGroup]) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .default
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.placeReuseIdentifier
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.clusterReuseIdentifier
        )

        context.coordinator.installControls(on: mapView)
        context.coordinator.updateAnnotations(on: mapView, places: places)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAnnotations(on: mapView, places: places)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let placeReuseIdentifier = "PlaceAnnotationView"
        static let clusterReuseIdentifier = "PlaceClusterAnnotationView"

        private enum Layout {
            static let controlsInset: CGFloat = 16
            static let controlSpacing: CGFloat = 10
            static let singlePlaceZoomMeters: CLLocationDistance = 2200
        }

        private enum Tags {
            static let compass = 9101
            static let tracking = 9102
        }

        var parent: ClusteredPlacesMapView
        private var lastPlaceSignature: String?

        init(parent: ClusteredPlacesMapView) {
            self.parent = parent
        }

        func installControls(on mapView: MKMapView) {
            guard mapView.viewWithTag(Tags.compass) == nil,
                  mapView.viewWithTag(Tags.tracking) == nil else {
                return
            }

            let compass = MKCompassButton(mapView: mapView)
            compass.compassVisibility = .adaptive
            compass.tag = Tags.compass
            compass.translatesAutoresizingMaskIntoConstraints = false
            mapView.addSubview(compass)

            let tracking = MKUserTrackingButton(mapView: mapView)
            tracking.tag = Tags.tracking
            tracking.translatesAutoresizingMaskIntoConstraints = false
            tracking.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.88)
            tracking.layer.cornerRadius = 10
            tracking.clipsToBounds = true
            mapView.addSubview(tracking)

            NSLayoutConstraint.activate([
                compass.topAnchor.constraint(
                    equalTo: mapView.safeAreaLayoutGuide.topAnchor,
                    constant: Layout.controlsInset
                ),
                compass.trailingAnchor.constraint(
                    equalTo: mapView.trailingAnchor,
                    constant: -Layout.controlsInset
                ),
                tracking.topAnchor.constraint(
                    equalTo: compass.bottomAnchor,
                    constant: Layout.controlSpacing
                ),
                tracking.trailingAnchor.constraint(
                    equalTo: compass.trailingAnchor
                )
            ])
        }

        func updateAnnotations(on mapView: MKMapView, places: [PlaceMemoryGroup]) {
            let signature = places
                .map { "\($0.id)|\($0.latitude)|\($0.longitude)|\($0.memories.count)" }
                .joined(separator: ";")

            guard signature != lastPlaceSignature else { return }
            lastPlaceSignature = signature

            let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(existingAnnotations)

            let annotations = places.map(PlaceAnnotation.init)
            mapView.addAnnotations(annotations)
            fitVisibleRegion(on: mapView, with: annotations, animated: false)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.clusterReuseIdentifier,
                    for: cluster
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: cluster,
                    reuseIdentifier: Self.clusterReuseIdentifier
                )
                configureClusterView(view, for: cluster)
                return view
            }

            guard let placeAnnotation = annotation as? PlaceAnnotation else {
                return nil
            }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Self.placeReuseIdentifier,
                for: placeAnnotation
            ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                annotation: placeAnnotation,
                reuseIdentifier: Self.placeReuseIdentifier
            )
            configurePlaceView(view)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer {
                if let annotation = view.annotation {
                    mapView.deselectAnnotation(annotation, animated: false)
                }
            }

            if let cluster = view.annotation as? MKClusterAnnotation {
                let clusteredPlaces = cluster.memberAnnotations
                    .compactMap { ($0 as? PlaceAnnotation)?.place }
                    .sorted(by: sortPlaces)
                parent.onClusterSelect(clusteredPlaces)
                return
            }

            guard let annotation = view.annotation as? PlaceAnnotation else {
                return
            }

            parent.selectedPlace = annotation.place
        }

        private func configurePlaceView(_ view: MKMarkerAnnotationView) {
            view.canShowCallout = false
            view.clusteringIdentifier = "place-group"
            view.markerTintColor = .systemRed
            view.glyphImage = UIImage(systemName: "photo")
            view.displayPriority = .required
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
        }

        private func configureClusterView(_ view: MKMarkerAnnotationView, for cluster: MKClusterAnnotation) {
            view.canShowCallout = false
            view.clusteringIdentifier = nil
            view.markerTintColor = .label
            view.glyphImage = nil
            view.glyphText = "\(cluster.memberAnnotations.count)"
            view.displayPriority = .required
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
        }

        private func fitVisibleRegion(
            on mapView: MKMapView,
            with annotations: [PlaceAnnotation],
            animated: Bool
        ) {
            guard !annotations.isEmpty else { return }

            if annotations.count == 1, let annotation = annotations.first {
                let region = MKCoordinateRegion(
                    center: annotation.coordinate,
                    latitudinalMeters: Layout.singlePlaceZoomMeters,
                    longitudinalMeters: Layout.singlePlaceZoomMeters
                )
                mapView.setRegion(region, animated: animated)
                return
            }

            let rect = annotations.reduce(MKMapRect.null) { partialResult, annotation in
                let point = MKMapPoint(annotation.coordinate)
                let annotationRect = MKMapRect(
                    origin: point,
                    size: MKMapSize(width: 0, height: 0)
                )
                return partialResult.union(annotationRect)
            }

            if rect.isNull || (rect.size.width == 0 && rect.size.height == 0) {
                let region = MKCoordinateRegion(
                    center: annotations[0].coordinate,
                    latitudinalMeters: Layout.singlePlaceZoomMeters * 1.4,
                    longitudinalMeters: Layout.singlePlaceZoomMeters * 1.4
                )
                mapView.setRegion(region, animated: animated)
                return
            }

            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 72, left: 28, bottom: 72, right: 28),
                animated: animated
            )
        }

        private func sortPlaces(_ lhs: PlaceMemoryGroup, _ rhs: PlaceMemoryGroup) -> Bool {
            if lhs.memories.count == rhs.memories.count {
                return lhs.lastVisitedAt > rhs.lastVisitedAt
            }
            return lhs.memories.count > rhs.memories.count
        }
    }
}

private final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: PlaceMemoryGroup

    var coordinate: CLLocationCoordinate2D {
        place.coordinate
    }

    var title: String? {
        place.name
    }

    init(place: PlaceMemoryGroup) {
        self.place = place
    }
}
