//
//  TSLoader.swift
//  CustomPlayer
//
//  Created by bumslap on 29/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class TSLoader: NSObject {
    
    private let url: URL
    private let httpConnection: HTTPConnetion
    
    private var masterPlaylist: MasterPlaylist?
    private var currentPlayingItemIndex: ListIndex?
    private var currentMediaPlaylist: MediaPlaylist?
    private var isLoaderReady: Bool = false
    
    private lazy var m3u8Parser = M3U8Parser(url: url)
  
    init(url: URL) {
        self.url = url
        self.httpConnection = HTTPConnetion()
        super.init()
    }
  
    
    func initializeLoader(completion: @escaping () -> Void) {
        m3u8Parser.parseMasterPlaylist { [weak self] (result, response) in
            guard let self = self else { return }
            switch result {
            case .failure:
                assertionFailure("fail to get masetPlaylist")
                
            case .success(let playlist):
                self.masterPlaylist = playlist
                // TODO: Calc net speed
                self.currentMediaPlaylist = playlist.mediaPlaylists[1]
                self.currentPlayingItemIndex = ListIndex(gear: 1, index: 0)
                guard let mediaPlaylist = self.currentMediaPlaylist else { return }
                self.m3u8Parser.parseMediaPlaylist(list: mediaPlaylist) {
                    self.isLoaderReady = true
                    completion()
                }
            }
        }
    }
    
    func fetchTsStream(completion: @escaping (Result<[TSStream], Error>) -> Void) {
        guard isLoaderReady else {
            completion(.failure(APIError.waitRequest))
            return
        }
        guard let currentPlaylistIndex = self.currentPlayingItemIndex else { return }
        guard let tempPlaylistPath = masterPlaylist?
            .mediaPlaylists[currentPlaylistIndex.gear]
            .videoMediaSegments[currentPlaylistIndex.index].path else { return }
        guard let url = URL(string: tempPlaylistPath) else { return }
        httpConnection.request(url: url) { (result, response) in
            switch result {
            case .failure:
                completion(.failure(APIError.requestFailed))
                
            case .success(let tsData):
                let tsParser = TSParser(target: tsData)
                let tsStream = tsParser.decode()
                completion(.success(tsStream))
            }
        }
    }
    
    
}
