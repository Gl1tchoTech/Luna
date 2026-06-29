//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import SwiftUI
import Kingfisher

@main
struct SoraApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager.shared
    @StateObject private var favouriteManager = FavouriteManager.shared

#if !os(tvOS)
    @AppStorage("showKanzen") private var showKanzen: Bool = false
    let kanzen = KanzenEngine();
#endif
    
    @AppStorage("hasImportedAnimetsuModule") private var hasImportedAnimetsuModule: Bool = false
    
    private let animetsuJSONURL = "https://git.luna-app.eu/50n50/sources/raw/branch/main/gojowtf/gojowtf.json"

    var body: some Scene {
        WindowGroup {
#if os(tvOS)
            ContentView()
                .task {
                    await importAnimetsuModuleIfNeeded()
                }
#else
            if showKanzen {
                KanzenMenu().environmentObject(settings).environmentObject(moduleManager).environmentObject(favouriteManager)
                    .environment(\.managedObjectContext, favouriteManager.container.viewContext)
                    .accentColor(settings.accentColor)
                    .task {
                        await importAnimetsuModuleIfNeeded()
                    }
            } else {
                ContentView()
                    .task {
                        await importAnimetsuModuleIfNeeded()
                    }
            }
#endif
        }
    }
    
    private func importAnimetsuModuleIfNeeded() async {
        guard !hasImportedAnimetsuModule else { return }
        
        await ServiceManager.shared.downloadService(from: animetsuJSONURL)
        // Small delay to ensure the service is saved before activating
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Activate the service if it was downloaded
        if let service = ServiceManager.shared.services.first(where: { $0.url == animetsuJSONURL }),
           !service.isActive {
            ServiceManager.shared.setServiceState(service, isActive: true)
        }
        
        await MainActor.run {
            hasImportedAnimetsuModule = true
        }
    }
}
