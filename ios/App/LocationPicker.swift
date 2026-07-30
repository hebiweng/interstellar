@preconcurrency import CoreLocation
@preconcurrency import MapKit
import SwiftUI

struct LocationSelection: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timezoneID: String
}

@MainActor
final class LocationSearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address]
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> LocationSelection? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            guard let item = response.mapItems.first else { return nil }
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            return LocationSelection(
                name: item.name ?? completion.title,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneID: item.timeZone?.identifier ?? TimeZone.current.identifier
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func resolve(_ coordinate: CLLocationCoordinate2D) async -> LocationSelection? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            let placemark = placemarks.first
            let parts = [
                placemark?.locality,
                placemark?.administrativeArea,
                placemark?.country,
            ]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }
            return LocationSelection(
                name: parts.isEmpty ? String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude) : parts.joined(separator: ", "),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneID: placemark?.timeZone?.identifier ?? TimeZone.current.identifier
            )
        } catch {
            errorMessage = error.localizedDescription
            return LocationSelection(
                name: String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneID: TimeZone.current.identifier
            )
        }
    }
}

@MainActor
final class CurrentLocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var isLocating = false
    @Published private(set) var selection: LocationSelection?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is disabled in Settings."
        @unknown default:
            errorMessage = "Location is currently unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
        {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied
            || manager.authorizationStatus == .restricted
        {
            isLocating = false
            errorMessage = "Location access is disabled in Settings."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        guard let location = locations.last else { return }
        selection = LocationSelection(
            name: "Current Location",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timezoneID: TimeZone.current.identifier
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = error.localizedDescription
    }
}

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = LocationSearchService()
    @StateObject private var currentLocation = CurrentLocationService()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selection: LocationSelection?
    let language: AppLanguage
    let onSelect: (LocationSelection) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $camera) {
                        UserAnnotation()
                        if let selection {
                            Marker(
                                selection.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: selection.latitude,
                                    longitude: selection.longitude
                                )
                            )
                            .tint(AppTheme.violet)
                        }
                    }
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                        MapUserLocationButton()
                    }
                    .onTapGesture { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        Task {
                            selection = await service.resolve(coordinate)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 8) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.muted)
                        TextField(
                            localized("Search a city or address", "搜索城市或地址", language: language),
                            text: $service.query
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        if service.isResolving {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))

                    if !service.query.isEmpty, !service.results.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(service.results.prefix(6), id: \.self) { result in
                                    Button {
                                        Task {
                                            if let resolved = await service.resolve(result) {
                                                select(resolved)
                                                service.query = ""
                                            }
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    Divider().overlay(AppTheme.line)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                        .padding(.horizontal, 13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    }

                    if let selection {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AppTheme.violet)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(selection.timezoneID)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                VStack {
                    Spacer()
                    HStack {
                        Button {
                            currentLocation.request()
                        } label: {
                            Label(
                                localized("My location", "我的位置", language: language),
                                systemImage: "location.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(height: 44)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(localized("Tap the map to choose", "点击地图选择位置", language: language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 13)
                            .frame(height: 44)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .padding(14)
                }

                if let message = service.errorMessage ?? currentLocation.errorMessage {
                    Text(
                        language == .english
                            ? message
                            : "无法获取地点信息，请检查定位权限或网络后重试。"
                    )
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 340)
                }
            }
            .navigationTitle(localized("Choose location", "选择地点", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Cancel", "取消", language: language)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Done", "完成", language: language)) {
                        if let selection {
                            onSelect(selection)
                            dismiss()
                        }
                    }
                    .disabled(selection == nil)
                }
            }
            .onAppear {
                currentLocation.request()
            }
            .onChange(of: currentLocation.selection) { _, location in
                guard let location else { return }
                Task {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    selection = await service.resolve(coordinate)
                    if let selection {
                        select(selection)
                    }
                }
            }
        }
    }

    private func select(_ location: LocationSelection) {
        selection = location
        camera = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        )
    }
}
