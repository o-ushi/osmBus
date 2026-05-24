import Foundation

struct Destination: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double

    var id: String {
        "\(name)|\(latitude)|\(longitude)"
    }
}
