//
//  DownloadsView.swift
//  Sora
//

import SwiftUI
import AVKit
import Sybau
import Kingfisher

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: DownloadedItem?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if downloadManager.downloads.isEmpty && downloadManager.activeProgress.isEmpty {
                    emptyView
                } else {
                    downloadsList
                }
            }
            .navigationTitle("Downloads")
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Downloads")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("Downloaded episodes and movies will appear here.\nUse the download button on any movie or episode to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Downloads List
    
    private var downloadsList: some View {
        List {
            // Active downloads
            if !downloadManager.activeProgress.isEmpty {
                Section("Downloading") {
                    ForEach(Array(downloadManager.activeProgress.values), id: \.id) { progress in
                        activeDownloadRow(progress)
                    }
                }
            }
            
            // Completed downloads grouped by show/movie
            if !downloadManager.downloads.isEmpty {
                let grouped = groupedDownloads()
                ForEach(grouped.keys.sorted(by: { (a, b) -> Bool in
                    guard let itemA = grouped[a]?.first, let itemB = grouped[b]?.first else { return false }
                    return itemA.downloadedAt > itemB.downloadedAt
                }), id: \.self) { key in
                    Section {
                        ForEach(grouped[key] ?? []) { item in
                            downloadedRow(item)
                        }
                        .onDelete { indexSet in
                            if let items = grouped[key] {
                                for index in indexSet {
                                    let item = items[index]
                                    downloadManager.deleteDownload(id: item.id)
                                }
                            }
                        }
                    } header: {
                        if let first = grouped[key]?.first {
                            Text(first.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Delete Download", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    downloadManager.deleteDownload(id: item.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this download? This cannot be undone.")
        }
    }
    
    // MARK: - Active Download Row
    
    private func activeDownloadRow(_ progress: DownloadProgress) -> some View {
        HStack(spacing: 12) {
            // Poster
            if let posterPath = progress.posterPath, let url = URL(string: posterPath) {
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.6)))
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 75)
                    .overlay(
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(progressSubtitle(progress))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 2) {
                    ProgressView(value: progress.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    
                    HStack {
                        Text(formatBytes(progress.downloadedBytes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(progress.totalBytes))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                downloadManager.cancelDownload(id: progress.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Downloaded Row
    
    private func downloadedRow(_ item: DownloadedItem) -> some View {
        HStack(spacing: 12) {
            // Poster
            if let posterPath = item.posterPath, !posterPath.isEmpty {
                let imageBaseURL = "https://image.tmdb.org/t/p/original"
                KFImage(URL(string: posterPath.hasPrefix("http") ? posterPath : imageBaseURL + posterPath))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 75)
                    .overlay(
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displaySubtitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(formatBytes(item.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Play button
                Button(action: {
                    playDownloadedItem(item)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                }
                
                // Context menu
                Menu {
                    // Export
                    Button(action: {
                        exportURL = item.localFileURL
                        showingShareSheet = true
                    }) {
                        Label("Export to Files", systemImage: "square.and.arrow.up")
                    }
                    
                    // Export season as zip
                    if item.mediaType == .tvShow {
                        let seasonItems = downloadManager.downloads.filter {
                            $0.seasonKey == item.seasonKey
                        }
                        if seasonItems.count > 1 {
                            Button(action: {
                                if let zipURL = downloadManager.exportAsZip(seasonKey: item.seasonKey, items: seasonItems) {
                                    exportURL = zipURL
                                    showingShareSheet = true
                                }
                            }) {
                                Label("Export Season as ZIP", systemImage: "doc.zipper")
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Delete
                    Button(role: .destructive, action: {
                        itemToDelete = item
                        showingDeleteAlert = true
                    }) {
                        Label("Delete Download", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func groupedDownloads() -> [String: [DownloadedItem]] {
        var result: [String: [DownloadedItem]] = [:]
        for item in downloadManager.downloads {
            if item.mediaType == .tvShow {
                result[item.seasonKey, default: []].append(item)
            } else {
                result["movie_\(item.id)", default: []].append(item)
            }
        }
        return result
    }
    
    private func progressSubtitle(_ progress: DownloadProgress) -> String {
        switch progress.mediaType {
        case .movie:
            return "Movie"
        case .tvShow:
            if let season = progress.seasonNumber, let episode = progress.episodeNumber {
                return "S\(season)E\(episode)"
            }
            return "Episode"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func playDownloadedItem(_ item: DownloadedItem) {
        let playerVC = NormalPlayer()
        let asset = AVURLAsset(url: item.localFileURL)
        let item2 = AVPlayerItem(asset: asset)
        playerVC.player = AVPlayer(playerItem: item2)
        
        var mediaInfo: MediaInfo?
        if item.mediaType == .movie {
            mediaInfo = .movie(id: item.tmdbId, title: item.title)
        } else if let season = item.seasonNumber, let episode = item.episodeNumber {
            mediaInfo = .episode(showId: item.tmdbId, showTitle: item.title, seasonNumber: season, episodeNumber: episode)
        }
        playerVC.mediaInfo = mediaInfo
        playerVC.modalPresentationStyle = .fullScreen
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.topmostViewController().present(playerVC, animated: true) {
                playerVC.player?.play()
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
