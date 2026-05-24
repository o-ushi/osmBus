import Foundation

enum OsmBusDeepLink {
    static let scheme = "osmbus"
    static let destinationHost = "destination"

    static func parseDestination(from url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        func value(for name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        guard let name = value(for: "name")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              let latString = value(for: "lat"),
              let lngString = value(for: "lng"),
              let latitude = Double(latString),
              let longitude = Double(lngString),
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude) else {
            return nil
        }

        let subtitle = value(for: "subtitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Destination(
            name: name,
            subtitle: subtitle?.isEmpty == false ? subtitle : nil,
            latitude: latitude,
            longitude: longitude
        )
    }
}
