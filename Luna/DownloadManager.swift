//
//  DownloadManager.swift
//  Sora
//

import Foundation
import Combine
import UniformTypeIdentifiers

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadedItem] = []
    @Published var activeProgress: [UUID: DownloadProgress] = [:]
    
    private var urlSession: URLSession!
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var taskMetadata: [UUID: DownloadProgress] = [:]
    
    static let downloadsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }()
    
    private let downloadsFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("downloaded_items.json")
    }()
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadDownloads()
    }
    
    // MARK: - Persistence
    
    private func loadDownloads() {
        guard let data = try? Data(contentsOf: downloadsFileURL) else { return }
        do {
            let items = try JSONDecoder().decode([DownloadedItem].self, from: data)
            downloads = items.filter { FileManager.default.fileExists(atPath: $0.localFileURL.path) }
            // Clean up orphaned files
            let validFiles = Set(downloads.map { $0.fileName })
            if let existingFiles = try? FileManager.default.contentsOfDirectory(atPath: Self.downloadsDirectory.path) {
                for file in existingFiles where !validFiles.contains(file) {
                    try? FileManager.default.removeItem(at: Self.downloadsDirectory.appendingPathComponent(file))
                }
            }
            saveDownloads()
        } catch {
            print("Failed to load downloads: \(error)")
        }
    }
    
    private func saveDownloads() {
        do {
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: downloadsFileURL)
        } catch {
            print("Failed to save downloads: \(error)")
        }
    }
    
    // MARK: - Download
    
    func startDownload(streamURL: URL, metadata: DownloadProgress) -> UUID {
        let id = metadata.id
        
        // Don't download if already exists
        if downloads.contains(where: { $0.id == id }) {
            return id
        }
        
        let task = urlSession.downloadTask(with: streamURL)
        taskMetadata[id] = metadata
        downloadTasks[id] = task
        
        var progress = metadata
        progress.progress = 0
        progress.downloadedBytes = 0
        activeProgress[id] = progress
        
        task.resume()
        return id
    }
    
    func cancelDownload(id: UUID) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)
        taskMetadata.removeValue(forKey: id)
        activeProgress.removeValue(forKey: id)
    }
    
    private func completeDownload(id: UUID, location: URL) {
        guard let metadata = taskMetadata[id] else { return }
        
        let fileExtension = location.pathExtension.isEmpty ? "mp4" : location.pathExtension
        let safeTitle = metadata.title.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        var fileName: String
        
        switch metadata.mediaType {
        case .movie:
            fileName = "\(safeTitle).\(fileExtension)"
        case .tvShow:
            let season = metadata.seasonNumber ?? 0
            let episode = metadata.episodeNumber ?? 0
            fileName = "\(safeTitle)_S\(season)E\(episode).\(fileExtension)"
        }
        
        let destination = Self.downloadsDirectory.appendingPathComponent(fileName)
        
        // Remove if exists
        try? FileManager.default.removeItem(at: destination)
        
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            print("Failed to move downloaded file: \(error)")
            return
        }
        
        let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
        
        let item = DownloadedItem(
            id: id,
            tmdbId: metadata.tmdbId,
            title: metadata.title,
            mediaType: metadata.mediaType,
            seasonNumber: metadata.seasonNumber,
            episodeNumber: metadata.episodeNumber,
            episodeName: metadata.episodeName,
            posterPath: metadata.posterPath,
            fileName: fileName,
            fileSize: fileSize,
            downloadedAt: Date()
        )
        
        DispatchQueue.main.async {
            self.downloads.append(item)
            self.activeProgress.removeValue(forKey: id)
            self.saveDownloads()
        }
        
        downloadTasks.removeValue(forKey: id)
        taskMetadata.removeValue(forKey: id)
    }
    
    func deleteDownload(id: UUID) {
        guard let item = downloads.first(where: { $0.id == id }) else { return }
        
        try? FileManager.default.removeItem(at: item.localFileURL)
        downloads.removeAll { $0.id == id }
        saveDownloads()
    }
    
    func isDownloaded(tmdbId: Int, seasonNumber: Int?, episodeNumber: Int?) -> Bool {
        downloads.contains { item in
            item.tmdbId == tmdbId &&
            item.seasonNumber == seasonNumber &&
            item.episodeNumber == episodeNumber
        }
    }
    
    func getDownload(tmdbId: Int, seasonNumber: Int?, episodeNumber: Int?) -> DownloadedItem? {
        downloads.first { item in
            item.tmdbId == tmdbId &&
            item.seasonNumber == seasonNumber &&
            item.episodeNumber == episodeNumber
        }
    }    // MARK: - Export
    
    func exportAsZip(seasonKey: String, items: [DownloadedItem]) -> URL? {
        guard !items.isEmpty else { return nil }
        
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(items.first?.title ?? "Season").zip")
        try? FileManager.default.removeItem(at: zipURL)
        
        // Use libcompression or a simple zip utility
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        for item in items.sorted(by: { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) }) {
            let dest = tempDir.appendingPathComponent(item.fileName)
            try? FileManager.default.copyItem(at: item.localFileURL, to: dest)
        }
        
        // Use system zip via Process or ditto
        let tempZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(items.first?.title ?? "Season").zip")
        try? FileManager.default.removeItem(at: tempZip)
        
        // Create zip using Coordinator + NSFileCoordinator
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { (zipURL) in
            try? FileManager.default.copyItem(at: zipURL, to: tempZip)
        }
        
        try? FileManager.default.removeItem(at: tempDir)
        
        return error == nil ? tempZip : nil
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Find the matching task
        for (id, task) in downloadTasks where task == downloadTask {
            completeDownload(id: id, location: location)
            break
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        for (id, task) in downloadTasks where task == downloadTask {
            DispatchQueue.main.async {
                var progress = self.activeProgress[id]
                if totalBytesExpectedToWrite > 0 {
                    progress?.totalBytes = totalBytesExpectedToWrite
                    progress?.downloadedBytes = totalBytesWritten
                    progress?.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                }
                self.activeProgress[id] = progress
            }
            break
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Download error: \(error)")
            for (id, downloadTask) in downloadTasks where downloadTask == task {
                DispatchQueue.main.async {
                    self.activeProgress.removeValue(forKey: id)
                }
                downloadTasks.removeValue(forKey: id)
                taskMetadata.removeValue(forKey: id)
                break
            }
        }
    }
}
