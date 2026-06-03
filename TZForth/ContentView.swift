//
//  ContentView.swift
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
// ContentView.swift is a thin SwiftUI wrapper; the Forth engine it hosts
// (via ConsoleView) is TZForth, respecting Leif Bruder lbForth public-domain
// origins internally. See TZForth.swift header.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ConsoleView()
    }
}

#Preview {
    ContentView()
}
