//
//  M3U8Decoder.swift
//  CustomPlayer
//
//  Created by bumslap on 19/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class M3U8Decoder {
    
    private let url: String
    private let rawData: Data
    
    private var redableData: String {
        get {
            return rawData.convertToString
        }
    }
    private var baseURL: String {
        get {
            var splitedURL = url.split(separator: "/")
            splitedURL.remove(at: (splitedURL.count - 1))
            let newURL = String(splitedURL.joined(separator: "/"))
            return newURL
        }
    }
    
    init(rawData: Data, url: String) {
        self.url = url
        self.rawData = rawData
    }
    
    func parseMasterPlaylist() -> MasterPlaylist? {
        let splitedData = redableData
            .split(separator: "\n")
            .map {
            String($0)
        }
        let masterPlaylist = MasterPlaylist()
        var hasStreamInfo = false
        var currentMedialist: MediaPlaylist?
        
        for line in splitedData {
            if hasStreamInfo {
                guard let mediaPlaylist = currentMedialist else { return nil }
                if line.hasPrefix("http") {
                     mediaPlaylist.path = line
                } else {
                     mediaPlaylist.path = baseURL + "/\(line)"
                }
               
                masterPlaylist.mediaPlaylists.append(mediaPlaylist)
                hasStreamInfo = false
            }
            
            guard !line.isEmpty || !line.hasPrefix("#EXTM3U") else { continue }
            
            if line.hasPrefix("#EXT-X-VERSION") {
                guard let version = Int(String(line.split(separator: ":")[1])) else { continue }
                masterPlaylist.version = version
                
            } else if line.hasPrefix("#EXT-X-STREAM-INF") {
                hasStreamInfo = true
                let mediaplaylist = MediaPlaylist()
                let attributes = String(line.split(separator: ":")[1])
                mediaplaylist.parseMediaInfo(target: attributes)
                currentMedialist = mediaplaylist
                
            } else if line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF") {
                // URI - must be
            } else{
                //TODO: process another tag
            }
        }
        masterPlaylist.mediaPlaylists.sort()
        return masterPlaylist
    }
    
    func parseMediaPlaylist(list: MediaPlaylist, completion: @escaping () -> Void) {
        guard let stringURL = list.path, let url = URL(string: stringURL) else { return }
        let httpConnection = HTTPConnetion()
        httpConnection.request(url: url) { (result, response) in
            switch result {
            case .failure:
                print("")
            case .success(let data):
                let splitedData = data
                    .convertToString
                    .split(separator: "\n").map {
                        String($0)
                }
                
                var hasStreamInfo = false
                var currentMediaSegment: MediaSegment?
                
                for line in splitedData {
                    if hasStreamInfo {
                        guard let mediaSegment = currentMediaSegment else { return }
                        var splitedURL = list.path!.split(separator: "/")
                        splitedURL.remove(at: (splitedURL.count - 1))
                        let newURL = String(splitedURL.joined(separator: "/"))
                        mediaSegment.path = newURL + "/\(line)"
                        list.mediaSegments.append(mediaSegment)
                        hasStreamInfo = false
                    }
                    guard !line.isEmpty || !line.hasPrefix("#EXTM3U") else { continue }
                    
                    if line.hasPrefix("#EXT-X-VERSION") {
                        guard let version = Int(String(line.split(separator: ":")[1])) else { continue }
                        list.version = version
                        
                    } else if line.hasPrefix("#EXT-X-TARGETDURATION"){
                        guard let duration = Int(String(line.split(separator: ":")[1])) else { continue }
                        list.targetDuration = duration
                        
                    } else if line.hasPrefix("#EXTINF") {
                        let mediaSegment = MediaSegment()
                        let value = String(line.split(separator: ":")[1])
                        mediaSegment.duration = Float(value)
                        currentMediaSegment = mediaSegment
                        hasStreamInfo = true
                        
                    } else if line.hasPrefix("#EXT-X-BITRATE") {
                      hasStreamInfo = true
                      
                    } else if line.hasPrefix("#EXT-X-BYTERANGE") {
                        hasStreamInfo = true
                       
                    } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE") {
                        // URI - must be
                    } else{
                        //TODO: process another tag
                    }
                }
                completion() 
            }
        }
    }
}
