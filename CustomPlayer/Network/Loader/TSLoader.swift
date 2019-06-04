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
    private let networkChecker: NetworkChecker = NetworkChecker.shared
    private let policy: NetworkLoadPolicy
    
    private var masterPlaylist: MasterPlaylist?
    private var currentPlayingItemIndex: ListIndex?
    private var currentMediaPlaylist: MediaPlaylist?
    private var isLoaderReady: Bool = false
    
    private lazy var m3u8Parser = M3U8Parser(url: url)
  
    init(url: URL) {
        self.url = url
        self.httpConnection = HTTPConnetion()
        self.policy = NetworkLoadPolicy()
        super.init()
        self.policy.delegate = self
    }
  
    
    func initializeLoader(completion: @escaping () -> Void) {
        m3u8Parser.parseMasterPlaylist { [weak self] (result, response) in
            guard let self = self else { return }
            switch result {
            case .failure:
                assertionFailure("fail to get masetPlaylist")
                
            case .success(let playlist):
                self.masterPlaylist = playlist
                let gear = self.policy.selectFirstPlaylistGear()
                self.currentMediaPlaylist = playlist.mediaPlaylists[gear]
                self.currentPlayingItemIndex = ListIndex(gear: gear, index: 0)
                guard let mediaPlaylist = self.currentMediaPlaylist else { return }
                self.m3u8Parser.parseMediaPlaylist(list: mediaPlaylist) {
                    self.isLoaderReady = true
                    completion()
                }
            }
        }
    }
    
    func fetchTsStream(completion: @escaping (Result<[DataStream]?, Error>) -> Void) {
        guard isLoaderReady else {
            completion(.failure(APIError.waitRequest))
            return
        }
        
        guard let currentPlaylistIndex = currentPlayingItemIndex else { return }
       
        let gear = policy.shouldUpdateGear()
        if gear == -1 { return }
        
        guard let targetMediaPlaylist = masterPlaylist?
            .mediaPlaylists[gear] else { return }
        
        if targetMediaPlaylist.videoMediaSegments.count < currentPlaylistIndex.index {
            completion(.success(nil))
        }
        
        if !targetMediaPlaylist.isParsed {
            m3u8Parser.parseMediaPlaylist(list: targetMediaPlaylist) {
                guard let path = targetMediaPlaylist
                    .videoMediaSegments[currentPlaylistIndex.index].path else {
                        completion(.failure(APIError.urlFailure))
                        return
                }
                guard let url = URL(string: path) else { return }
                self.httpConnection.request(url: url) { (result, response) in
                    switch result {
                    case .failure:
                        completion(.failure(APIError.requestFailed))
                        
                    case .success(let tsData):
                        let tsParser = TSParser(target: tsData)
                        let tsStream = tsParser.parse()
                        completion(.success(tsStream))
                        self.currentPlayingItemIndex = ListIndex(gear: currentPlaylistIndex.gear, index: currentPlaylistIndex.index + 1)
                    }
                }
            }
        } else {
            guard let path = targetMediaPlaylist
                .videoMediaSegments[currentPlaylistIndex.index].path else {
                    completion(.failure(APIError.urlFailure))
                    return
            }
            guard let url = URL(string: path) else { return }
            self.httpConnection.request(url: url) { (result, response) in
                switch result {
                case .failure:
                    completion(.failure(APIError.requestFailed))
                    
                case .success(let tsData):
                    let tsParser = TSParser(target: tsData)
                    let tsStream = tsParser.parse()
                    completion(.success(tsStream))
                    self.currentPlayingItemIndex = ListIndex(gear: currentPlaylistIndex.gear, index: currentPlaylistIndex.index + 1)
                }
            }
        }
    }
}

extension TSLoader: NetworkPolicyDelegate {
    func currentNetworkSpeed() -> Double {
        return networkChecker.currentNetworkSpeed
    }
    
    func numberOfPlaylist() -> Int {
        guard let size = masterPlaylist?.mediaPlaylists.count else {
            return 0
        }
        return size
    }
    
    func samplingNetworSpeedkHistory(limit number: Int) -> [Double] {
        let history = networkChecker.networkSpeedHistory
        if number > history.count {
            return history
        } else {
            let index = history.count - number
            return Array(history[index...])
        }
    }
    
}
