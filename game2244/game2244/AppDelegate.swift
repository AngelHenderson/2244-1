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
}
