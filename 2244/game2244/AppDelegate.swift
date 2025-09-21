//
//  AppDelegate.swift
//  game2244
//
//  Created by Angel Henderson on 9/9/25.
//

import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase as early as possible
        print("🔥 Configuring Firebase in AppDelegate...")
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully in AppDelegate")
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save all progress when app goes to background
        NotificationCenter.default.post(name: .saveProgress, object: nil)
        print("📱 App backgrounded - progress saving triggered")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Emergency save before app terminates
        NotificationCenter.default.post(name: .saveProgress, object: nil)
        UserDefaults.standard.synchronize() // Force immediate save
        print("🚨 App terminating - emergency progress save")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let saveProgress = Notification.Name("SaveProgress")
}
