//
//  TZForthApp.swift
//  TZForth
//
//  Created by Thomas Zimmer on 5/30/26.
//

//
// Public Domain Statement
//
// This software is released into the public domain.
//
// TZForth is free and unencumbered software dedicated to the public domain.
//
// TZForthApp.swift is the @main entry for the TZForth macOS app.
// The core engine (TZForth class) is based on Leif Bruder's public-domain
// lbForth model internally.
//
// See TZForth.swift for full credit and the original model link.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//

import SwiftUI
import AppKit

/// Quit when the user closes the last console window (typical single-window tool behavior).
/// Multiple windows remain possible via File → New Window for now, but closing the last one ends the app.
final class TZForthAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct TZForthApp: App {
    @NSApplicationDelegateAdaptor(TZForthAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Tools") {
                Button("CLS") {
                    NotificationCenter.default.post(name: .clearConsole, object: nil)
                }
                Button("EDIT") {
                    NotificationCenter.default.post(name: .toolsEdit, object: nil)
                }
                Button("FLOAD") {
                    NotificationCenter.default.post(name: .toolsFload, object: nil)
                }
                Button("CHDIR") {
                    NotificationCenter.default.post(name: .toolsChdir, object: nil)
                }
                Menu("AUTOLOAD") {
                    Button("VIEW AutoLoad Folder") {
                        NotificationCenter.default.post(name: .toolsViewAutoloadFolder, object: nil)
                    }
                }
                Menu("LIBRARY") {
                    Button("VIEW Library Folder") {
                        NotificationCenter.default.post(name: .toolsViewLibraryFolder, object: nil)
                    }
                }
                Divider()
                Button("RESET") {
                    NotificationCenter.default.post(name: .resetForth, object: nil)
                }
            }
        }
    }
}
