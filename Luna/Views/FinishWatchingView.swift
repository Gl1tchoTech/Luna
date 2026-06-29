//
//  FinishWatchingView.swift
//  Sora
//
//  Created for "Finish Watching" feature
//

import SwiftUI
import Kingfisher
import Sybau

struct FinishWatchingView: View {
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @StateObject private var tmdbService = TMDBService.shared
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if continueWatchingItems.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mediaPlaybackDidFinish)) { _ in
            loadItems()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Nothing to Finish")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Start watching something and come back here to continue where you left off.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Finish Watching")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ForEach(continueWatchingItems) { item in
                    FinishWatchingCard(item: item, tmdbService: tmdbService)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    private func loadItems() {
        continueWatchingItems = ProgressManager.shared.getContinueWatchingItems()
        isLoading = false
    }
}

struct FinishWatchingCard: View {
    let item: ContinueWatchingItem
    let tmdbService: TMDBService
    
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    @State private var backdropURL: String?
    @State private var logoURL: String?
    @State private var title: String = ""
    @State private var isLoaded: Bool = false
    @State private var showingSearchResults = false
    
    private var displayTitle: String {
        title.isEmpty ? item.title : title
    }
    
    private var selectedEpisodeForSearch: TMDBEpisode? {
        guard !item.isMovie,
              let seasonNumber = item.seasonNumber,
              let episodeNumber = item.episodeNumber else {
            return nil
        }
        
        return TMDBEpisode(
            id: Int("\(item.tmdbId)\(seasonNumber)\(episodeNumber)") ?? item.tmdbId,
            name: "",
            overview: nil,
            stillPath: nil,
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            airDate: nil,
            runtime: nil,
            voteAverage: 0,
            voteCount: 0
        )
    }
    
    var body: some View {
        Button {
            showingSearchResults = true
        } label: {
            HStack(spacing: 12) {
                // Poster/Backdrop
                ZStack {
                    if let backdropURL = backdropURL {
                        KFImage(URL(string: backdropURL))
                            .placeholder {
                                backdropPlaceholder
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        backdropPlaceholder
                    }
                }
                .frame(width: 140, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !item.isMovie, let season = item.seasonNumber, let episode = item.episodeNumber {
                        Text("Season \(season) · Episode \(episode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Movie")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * item.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        Text(item.remainingTime)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .padding(12)
            .applyLiquidGlassBackground(cornerRadius: 12)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadMediaDetails()
        }
        .sheet(isPresented: $showingSearchResults) {
            ModulesSearchResultsSheet(
                mediaTitle: displayTitle,
                originalTitle: nil,
                isMovie: item.isMovie,
                selectedEpisode: selectedEpisodeForSearch,
                tmdbId: item.tmdbId
            )
        }
    }
    
    @ViewBuilder
    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: item.isMovie ? "film" : "tv")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    private func loadMediaDetails() async {
        guard !isLoaded else { return }
        
        do {
            if item.isMovie {
                async let detailsTask = tmdbService.getMovieDetails(id: item.tmdbId)
                async let imagesTask = tmdbService.getMovieImages(id: item.tmdbId, preferredLanguage: selectedLanguage)
                
                let (details, images) = try await (detailsTask, imagesTask)
                
                await MainActor.run {
                    self.title = details.title
                    self.backdropURL = details.fullBackdropURL ?? details.fullPosterURL
                    if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                    self.isLoaded = true
                }
            } else {
                async let detailsTask = tmdbService.getTVShowDetails(id: item.tmdbId)
                async let imagesTask = tmdbService.getTVShowImages(id: item.tmdbId, preferredLanguage: selectedLanguage)
                
                let (details, images) = try await (detailsTask, imagesTask)
                
                await MainActor.run {
                    self.title = details.name
                    self.backdropURL = details.fullBackdropURL ?? details.fullPosterURL
                    if let logo = tmdbService.getBestLogo(from: images, preferredLanguage: selectedLanguage) {
                        self.logoURL = logo.fullURL
                    }
                    self.isLoaded = true
                }
            }
        } catch {
            await MainActor.run {
                self.title = item.isMovie ? "Movie" : "TV Show"
                self.isLoaded = true
            }
        }
    }
}

#Preview {
    FinishWatchingView()
}
