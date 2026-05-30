//
//  ContentView.swift
//  FPCForth
//
//  Created by Thomas Zimmer mini on 5/30/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

//FLOAD KERNEL1.SEQ.swift
//FLOAD VIDEO.SEQ
//FLOAD KERNEL2.SEQ
//FLOAD VIDEO2.SEQ
//FLOAD KERNEL3.SEQ
//FLOAD EXPAND.SEQ
//FLOAD EMMEXEC.SEQ
//FLOAD POINTER.SEQ
//FLOAD EQUCOLON.SEQ
//FLOAD SAVEREST.SEQ
//FLOAD HANDLES.SEQ
//FLOAD SEQREAD.SEQ
//FLOAD FPATH.SEQ
//FLOAD DEFAULT.SEQ
//FLOAD HCRITICA.SEQ
//FLOAD KERNEL4.SEQ       \ 05/25/90 tjz
