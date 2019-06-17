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
    
    
    var currentPlayingItemIndex: ListIndex?
    
    private var masterPlaylist: MasterPlaylist?
    private var currentMediaPlaylist: MediaPlaylist?
    private var isLoaderReady: Bool = false
    
    private let playlistCache = NSCache<NSString, MasterPlaylist>()
    //private let tsCache = NSCache<NSString, )>()
    
    private lazy var m3u8Parser = M3U8Parser()
    
    let semaphore = DispatchSemaphore(value: 1)
  
    init(url: URL) {
        self.url = url
        self.httpConnection = HTTPConnetion()
        self.policy = NetworkLoadPolicy()
        super.init()
        self.policy.delegate = self
       // playlistCache.countLimit = 30
    }
  
    
    func load(with url: URL, index: Int = 0, completion: @escaping () -> Void) {
        
        if let cachedPlaylist = playlistCache.object(forKey: url.absoluteString as NSString) {
            self.masterPlaylist = cachedPlaylist
            let gear = self.policy.selectFirstPlaylistGear()
            self.currentMediaPlaylist = cachedPlaylist.mediaPlaylists[gear]
            self.currentPlayingItemIndex = ListIndex(gear: gear, index: index)
            guard let mediaPlaylist = self.currentMediaPlaylist else { return }
            self.m3u8Parser.parseMediaPlaylist(list: mediaPlaylist) {
                self.isLoaderReady = true
                completion()
                return
            }
            
        } else {
            m3u8Parser.parseMasterPlaylist(with: url) { [weak self] (result, response) in
                guard let self = self else { return }
                switch result {
                case .failure:
                    assertionFailure("fail to get masetPlaylist")
                    
                case .success(let playlist):
                    self.masterPlaylist = playlist
                    self.playlistCache.setObject(playlist, forKey: url.absoluteString as NSString)
                    let gear = self.policy.selectFirstPlaylistGear()
                    self.currentMediaPlaylist = playlist.mediaPlaylists[gear]
                    self.currentPlayingItemIndex = ListIndex(gear: gear, index: index)
                    guard let mediaPlaylist = self.currentMediaPlaylist else { return }
                    self.m3u8Parser.parseMediaPlaylist(list: mediaPlaylist) {
                        self.isLoaderReady = true
                        completion()
                    }
                }
            }
        }
    }
    
    func fetchTsStream(completion: @escaping (Result<[DataStream], Error>) -> Void) -> Bool {
        
        
     
        guard isLoaderReady,
            let currentPlaylistIndex = currentPlayingItemIndex else {
            completion(.failure(APIError.waitRequest))
            return false
        }
        
        let gear = policy.shouldUpdateGear()
        
        if gear == -1 {
            completion(.failure(APIError.responseUnsuccessful))
            return false
        }

        guard let targetMediaPlaylist = masterPlaylist?
            .mediaPlaylists[gear] else {
                completion(.failure(APIError.invalidData))
                return false
                
        }

       
        if !targetMediaPlaylist.isParsed {
            m3u8Parser.parseMediaPlaylist(list: targetMediaPlaylist) {
                if targetMediaPlaylist.videoMediaSegments.count - 1 < currentPlaylistIndex.index {
                    completion(.failure(APIError.invalidData))
                    return
                }
                
                if targetMediaPlaylist.videoMediaSegments.count - 1 < currentPlaylistIndex.index {
                    completion(.failure(APIError.invalidData))
                    return
                }
                
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
                        
                        currentPlaylistIndex.index += 1
                        completion(.success(tsStream))
                    }
                }
            }
        } else {
            if targetMediaPlaylist.videoMediaSegments.count - 1 < currentPlaylistIndex.index {
                completion(.failure(APIError.invalidData))
                return false
            }
            
        
            guard let path = targetMediaPlaylist
                .videoMediaSegments[currentPlaylistIndex.index].path,
                let url = URL(string: path) else {
                    completion(.failure(APIError.urlFailure))
                    return false
            }
            
            self.httpConnection.request(url: url) { (result, response) in
                switch result {
                case .failure:
                    completion(.failure(APIError.requestFailed))
                    return
                case .success(let tsData):
                    
                    let tsParser = TSParser(target: tsData)
                    let tsStream = tsParser.parse()
                    currentPlaylistIndex.index += 1
                    completion(.success(tsStream))
                }
            }
        }
        return true
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
