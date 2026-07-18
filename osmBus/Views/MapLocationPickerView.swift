import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

enum MapPickRole {
    case origin
    case destination
}

struct MapLocationPickerView: View {
    let initialRole: MapPickRole
    let onPickOrigin: (Double, Double, String) -> Void
    let onPickDestination: (Destination) -> Void

    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var role: MapPickRole
    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @State private var pickedName: String?
    @State private var pickedSubtitle: String?
    @State private var isGeocoding = false
    @State private var geocoder = CLGeocoder()
    @State private var mapBox = GMSMapViewBox()

    init(
        initialRole: MapPickRole,
        onPickOrigin: @escaping (Double, Double, String) -> Void,
        onPickDestination: @escaping (Destination) -> Void
    ) {
        self.initialRole = initialRole
        self.onPickOrigin = onPickOrigin
        self.onPickDestination = onPickDestination
        _role = State(initialValue: initialRole)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                GoogleMapView(
                    polylines: [],
                    markers: pickerMarker.map { [$0] } ?? [],
                    onSetup: { mapView in
                        mapBox.view = mapView
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            mapBox.moveToCurrentLocation(coordinate: locationService.currentLocation)
                        }
                    },
                    onTap: { coordinate in
                        pickedCoordinate = coordinate
                        pickedName = nil
                        pickedSubtitle = nil
                        reverseGeocode(coordinate)
                    },
                    trialSignature: "maps-picker"
                )
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        MapLocationButton(mapBox: mapBox)
                            .padding(.trailing, 12)
                    }
                    bottomCard
                }
            }
            .navigationTitle(AppLocaleString.text("地図から選択", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Picker marker

    private var pickerMarker: GMapMarkerData? {
        guard let coord = pickedCoordinate else { return nil }
        return GMapMarkerData(
            id: "picked",
            coordinate: coord,
            icon: pinIcon(for: role),
            groundAnchor: CGPoint(x: 0.5, y: 1.0),
            zIndex: 10,
            title: pickedName ?? ""
        )
    }

    private func pinIcon(for role: MapPickRole) -> UIImage {
        let tint: UIColor = role == .origin ? .systemGreen : .systemRed
        let systemImage = role == .origin ? "location.fill" : "flag.checkered"
        let circleSize: CGFloat = 36
        let triangleHeight: CGFloat = 8
        let totalHeight = circleSize + triangleHeight
        let totalWidth = circleSize

        return UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight)).image { ctx in
            // Circle
            tint.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: circleSize - 4, height: circleSize - 4)).fill()

            // Triangle pointer
            let triPath = UIBezierPath()
            triPath.move(to: CGPoint(x: totalWidth / 2, y: totalHeight))
            triPath.addLine(to: CGPoint(x: totalWidth / 2 - 6, y: circleSize))
            triPath.addLine(to: CGPoint(x: totalWidth / 2 + 6, y: circleSize))
            triPath.close()
            tint.setFill()
            triPath.fill()

            // Icon
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            if let icon = UIImage(systemName: systemImage, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(
                    x: (totalWidth - icon.size.width) / 2,
                    y: (circleSize - icon.size.height) / 2
                ))
            }
        }
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(spacing: 12) {
            Picker(
                AppLocaleString.text("地図から選択", locale: locale),
                selection: $role
            ) {
                Text(AppLocaleString.text("地図_出発地", locale: locale)).tag(MapPickRole.origin)
                Text(AppLocaleString.text("地図_目的地", locale: locale)).tag(MapPickRole.destination)
            }
            .pickerStyle(.segmented)

            if let coord = pickedCoordinate {
                VStack(alignment: .leading, spacing: 4) {
                    nameRow(coord: coord)

                    Text(coordinateLabel(coord))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: confirm) {
                    Text(AppLocaleString.text(
                        role == .origin ? "地図_出発地に設定" : "地図_目的地に設定",
                        locale: locale
                    ))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(role == .origin ? .green : .blue)
                .disabled(isGeocoding)
            } else {
                Text(AppLocaleString.text("地図_タップヒント", locale: locale))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func nameRow(coord: CLLocationCoordinate2D) -> some View {
        if isGeocoding {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(AppLocaleString.text("地図_住所取得中", locale: locale))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(pickedName ?? coordinateLabel(coord))
                    .font(.headline)
                    .lineLimit(2)

                if let subtitle = pickedSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Geocoding

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        guard ThirdPartyDataConsent.isGranted else {
            pickedName = coordinateLabel(coordinate)
            pickedSubtitle = nil
            isGeocoding = false
            return
        }
        geocoder.cancelGeocode()
        isGeocoding = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            Task { @MainActor in
                self.isGeocoding = false
                guard let placemark = placemarks?.first else { return }
                let (name, subtitle) = self.extractPlaceInfo(from: placemark, coordinate: coordinate)
                self.pickedName = name
                self.pickedSubtitle = subtitle
            }
        }
    }

    private func extractPlaceInfo(
        from placemark: CLPlacemark,
        coordinate: CLLocationCoordinate2D
    ) -> (name: String, subtitle: String?) {
        let raw = placemark.name ?? ""

        let name: String
        if raw.isEmpty || raw.hasPrefix("〒") {
            name = placemark.subLocality
                ?? placemark.thoroughfare
                ?? placemark.locality
                ?? coordinateLabel(coordinate)
        } else {
            name = raw
        }

        let candidates = [placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !name.contains($0) }
        let subtitle = candidates.prefix(2).joined(separator: ", ")

        return (name, subtitle.isEmpty ? nil : subtitle)
    }

    // MARK: - Helpers

    private func coordinateLabel(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }

    private func confirm() {
        guard let coord = pickedCoordinate else { return }
        let name = pickedName ?? coordinateLabel(coord)
        switch role {
        case .origin:
            onPickOrigin(coord.latitude, coord.longitude, name)
        case .destination:
            onPickDestination(
                Destination(
                    name: name,
                    subtitle: pickedSubtitle,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            )
        }
        dismiss()
    }
}
