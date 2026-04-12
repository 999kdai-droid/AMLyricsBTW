import Foundation

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var playerPosition: Double

    static let empty = Track(title: "", artist: "", album: "", artworkURL: nil, playerPosition: 0)
}
