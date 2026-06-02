//
//  TZForthApp.swift
//  TZForth
//
//  Created by Thomas Zimmer mini on 5/30/26.
//

import SwiftUI

@main
struct TZForthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Tools") {
                Button("CLS") {
                    NotificationCenter.default.post(name: .clearConsole, object: nil)
                }
                // .keyboardShortcut("l", modifiers: [.command])
                Button("RESET") {
                    NotificationCenter.default.post(name: .resetForth, object: nil)
                }
            }
        }
    }
}
