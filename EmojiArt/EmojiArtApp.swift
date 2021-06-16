//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by H Hugo Falkman on 13/06/2021.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}
