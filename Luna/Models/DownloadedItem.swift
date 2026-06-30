//
//  DownloadedItem.swift
//  Sora
//

import Foundation

struct DownloadedItem: Codable, Identifiable, Equatable {
    let id: UUID
    let tmdbId: Int
    let title: String
    let mediaType: MediaType
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeName: String?
    let posterPath: String?
    let fileName: String
    let fileSize: Int64
    let downloadedAt: Date
    let duration: TimeInterval?
    
    var localFileURL: URL {
        DownloadManager.downloadsDirectory.appendingPathComponent(fileName)
    }
    
    var displaySubtitle: String {
        switch mediaType {
        case .movie:
            return "Movie"
        case .tvShow:
            if let season = seasonNumber, let episode = episodeNumber {
                var text = "S\(season)E\(episode)"
                if let name = episodeName, !name.isEmpty {
                    text += " - \(name)"
                }
                return text
            }
            return "Episode"
        }
    }
    
    var seasonKey: String {
        "\(tmdbId)_S\(seasonNumber ?? 0)"
    }
    
    init(id: UUID = UUID(),
         tmdbId: Int,
         title: String,
         mediaType: MediaType,
         seasonNumber: Int? = nil,
         episodeNumber: Int? = nil,
         episodeName: String? = nil,
         posterPath: String? = nil,
         fileName: String,
         fileSize: Int64 = 0,
         downloadedAt: Date = Date(),
         duration: TimeInterval? = nil) {
        self.id = id
        self.tmdbId = tmdbId
        self.title = title
        self.mediaType = mediaType
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.posterPath = posterPath
        self.fileName = fileName
        self.fileSize = fileSize
        self.downloadedAt = downloadedAt
        self.duration = duration
    }
    
    static func == (lhs: DownloadedItem, rhs: DownloadedItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum MediaType: String, Codable {
    case movie
    case tvShow
}

struct DownloadProgress: Codable {
    let id: UUID
    let tmdbId: Int
    let title: String
    let mediaType: MediaType
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeName: String?
    let posterPath: String?
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64
}
