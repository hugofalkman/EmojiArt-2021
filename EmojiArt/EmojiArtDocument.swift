//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by H Hugo Falkman on 13/06/2021.
//

import SwiftUI
import Combine

class EmojiArtDocument: ObservableObject {
    @Published private(set) var emojiArt: EmojiArtModel {
        didSet {
            scheduleAutoSave()
            if emojiArt.background != oldValue.background {
                fetchBackgroundImage()
            }
        }
    }
    
    private var autoSaveTimer: Timer?
    
    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: AutoSave.coalescingInterval, repeats: false) { _ in
            self.autoSave()
        }
    }
    
    private struct AutoSave {
        static let fileName = "Autosaved.emojiArt"
        static var url: URL? {
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return documentDirectory?.appendingPathComponent(fileName)
        }
        static let coalescingInterval = 5.0
    }
    
    private func autoSave() {
        if let url = AutoSave.url {
            save(to: url)
        }
    }
    
    private func save(to url:URL) {
        let selfId = "\(String(describing: self)).\(#function)"
        do {
            let data: Data = try emojiArt.json()
            print("\(selfId) json = \(String(data: data, encoding: .utf8) ?? "nil")")
            try data.write(to: url)
            print("\(selfId) completed")
        } catch let encodingError where encodingError is EncodingError {
            print("\(selfId) error = \(encodingError.localizedDescription) when encoding the EmojiArtModel as JSON")
        } catch {
            print("\(selfId) error = \(error)")
        }
    }
    
    init() {
        if let url = AutoSave.url, let autosavedEmojiArt = try? EmojiArtModel(url: url) {
            emojiArt = autosavedEmojiArt
            fetchBackgroundImage()
        } else {
            emojiArt = EmojiArtModel()
    //        emojiArt.addEmoji("😀", at: (-200, -100), size: 80)
    //        emojiArt.addEmoji("😷", at: (50, 100), size: 40)
        }
    }
    
    @Published var backgroundImage: UIImage?
    @Published var backgroundFetchStatus = BackgroundFetchStatus.idle
    
    enum BackgroundFetchStatus: Equatable {
        case idle
        case fetching
        case failed(URL)
    }
    
    private var fetchBackgroundImageCancellable: AnyCancellable?
    
    private func fetchBackgroundImage() {
        backgroundImage = nil
        switch emojiArt.background {
        case .url(let url):
            backgroundFetchStatus = .fetching
            fetchBackgroundImageCancellable?.cancel()
            let session = URLSession.shared
            let publisher = session.dataTaskPublisher(for: url)
                .map { data, URLResponse in UIImage(data: data) }
//                .replaceError(with: nil)
                .receive(on: DispatchQueue.main)
            
            fetchBackgroundImageCancellable = publisher
//                .assign(to: \EmojiArtDocument.backgroundImage, on: self)
                .sink(
                    receiveCompletion: { result in
                        switch result {
                        case .finished:
                            print("URLSession succeeded")
                        case .failure(let error):
                            print("URLSession failed: error = \(error)")
                        }
                    },
                    receiveValue: { [weak self] image in
                        self?.backgroundImage = image
                        self?.backgroundFetchStatus = image != nil ? .idle : .failed(url)
                    }
                )
            
//            DispatchQueue.global(qos: .userInitiated).async {
//                let imageData = try? Data(contentsOf: url)
//                DispatchQueue.main.async { [weak self] in
//                    if self?.emojiArt.background == EmojiArtModel.Background.url(url) {
//                        self?.backgroundFetchStatus = .idle
//                        if imageData != nil {
//                            self?.backgroundImage = UIImage(data: imageData!)
//                        }
//                        if self?.backgroundImage == nil {
//                            self?.backgroundFetchStatus = .failed(url)
//                        }
//                    }
//                }
//            }
        
        case .imageData(let data):
            backgroundImage = UIImage(data: data)
        case .blank:
            break
        }
    }
    
    var emojis: [EmojiArtModel.Emoji] { emojiArt.emojis }
    var background: EmojiArtModel.Background { emojiArt.background }
    
    // MARK: - Intent(s)
    
    func setBackground(_ background: EmojiArtModel.Background) {
        emojiArt.background = background
    }
    
    func addEmoji(_ emoji: String, at location: (x: Int, y: Int), size: CGFloat) {
        emojiArt.addEmoji(emoji, at: location, size: Int(size))
    }
    
    func moveEmoji(_ emoji: EmojiArtModel.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y += Int(offset.height)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArtModel.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].size = Int((CGFloat(emojiArt.emojis[index].size) * scale).rounded(.toNearestOrAwayFromZero))
        }
    }
}
