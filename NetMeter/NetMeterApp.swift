//
//  NetMeterApp.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/11/25.
//

import SwiftUI

@main
struct NetMeterApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
