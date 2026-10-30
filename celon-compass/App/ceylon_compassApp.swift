//
//  celon_compassApp.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import SwiftUI
import CoreData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct celon_compassApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  let persistenceController = PersistenceController.shared
  @State private var lockState = AppLockState()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
        RootView(lockState: lockState)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
    .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .background {
            lockState.lock()
        }
        if newPhase == .active {
            Task { await SyncCoordinator.shared.pushNow() }
        }
    }
  }
}
