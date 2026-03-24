//
//  ScanningerApp.swift
//  Scanninger
//
//  Created by Yeghishe Grigoryan on 13.01.26.
//

import SwiftUI
import SwiftData

@main
struct ScanningerApp: App {
    init() {
        AppFlowBootstrap.migrateFromLegacyIfNeeded()
        // Premium access: `AppStore.sync()` + `Transaction.currentEntitlements` (not UserDefaults).
        Task { @MainActor in
            await SubscriptionManager.shared.synchronizeEntitlementsOnLaunch()
        }
    }

    var body: some Scene {
        let schema = Schema([InvoiceModel.self, LineItemModel.self, BusinessProfileModel.self, ClientModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        
        return WindowGroup {
            ScanningerRootView()
        }
        .modelContainer(container)
    }
}
