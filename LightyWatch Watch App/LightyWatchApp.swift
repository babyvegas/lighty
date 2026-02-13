//
//  LightyWatchApp.swift
//  LightyWatch Watch App
//
//  Created by Donovan Efrain Barrientos Abarca on 06/02/26.
//

import SwiftUI

@main
struct LightyWatch_Watch_AppApp: App {
    @StateObject private var connectivity = WatchConnectivityCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
