//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    var body: some View {
#if compiler(>=6.0)
        if #available(iOS 26.0, tvOS 26.0, *) {
            TabView {
                Tab("Home", systemImage: "house.fill") {
                    HomeView()
                }
                
                Tab("Continue", systemImage: "play.rectangle.fill") {
                    FinishWatchingView()
                }
                
                Tab("Library", systemImage: "books.vertical.fill") {
                    LibraryView()
                }
                
                Tab("Downloads", systemImage: "arrow.down.to.line") {
                    DownloadsView()
                }
                
                Tab("Search", systemImage: "magnifyingglass", role: .search) {
                    SearchView()
                }
                
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
#if !os(tvOS)
            .tabBarMinimizeBehavior(.onScrollDown)
#endif
            .accentColor(accentColorManager.currentAccentColor)
            
        } else {
            olderTabView
        }
#else
        olderTabView
#endif
    }
    
    private var olderTabView: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            FinishWatchingView()
                .tabItem {
                    Image(systemName: "play.rectangle.fill")
                    Text("Continue")
                }
            
            LibraryView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Library")
                }
            
            DownloadsView()
                .tabItem {
                    Image(systemName: "arrow.down.to.line")
                    Text("Downloads")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(accentColorManager.currentAccentColor)
    }
}

#Preview {
    ContentView()
}
