//
//  M3U8Decoder.swift
//  CustomPlayer
//
//  Created by bumslap on 19/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class M3U8Decoder {
    
    private var baseURL: String {
        get {
            var splitedURL = url.split(separator: "/")
            splitedURL.remove(at: (splitedURL.count - 1))
            let newURL = String(splitedURL.joined(separator: "/"))
            return newURL
        }
    }
    private let url: String
    private let rawData: Data
    private var redableData: String {
        get {
            return rawData.convertToString
        }
    }
    
    init(rawData: Data, url: String) {
        self.url = url
        self.rawData = rawData
        for line in redableData.split(separator: "\n") {
            print(line)
            print("")
        }
    }
    
    func parseMasterPlaylist() -> MasterPlaylist? {
        let splitedData = redableData.split(separator: "\n").map {
            String($0)
        }
        let masterPlaylist = MasterPlaylist()
        var hasStreamInfo = false
        var currentMedialist: MediaPlaylist?
        
        for line in splitedData {
            if hasStreamInfo {
                guard let mediaPlaylist = currentMedialist else { return nil }
                mediaPlaylist.path = baseURL + "/\(line)"
                masterPlaylist.mediaPlaylists.append(mediaPlaylist)
                hasStreamInfo = false
            }
            guard !line.isEmpty || !line.hasPrefix("#EXTM3U") else { return nil }
            
            if line.hasPrefix("#EXT-X-VERSION") {
               masterPlaylist.version = Int(String(line.split(separator: ":")[1]))!
            } else if line.hasPrefix("#EXT-X-STREAM-INF") {
                hasStreamInfo = true
                let mediaplaylist = MediaPlaylist()
                let value = String(line.split(separator: ":")[1])
                mediaplaylist.parseMediaInfo(target: value)
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
    
    func parseMediaPlaylist(list: MediaPlaylist) {
        guard let stringURL = list.path, let url = URL(string: stringURL) else { return }
        print("url is\(url)")
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                return
            }
            guard let data = data else { return }
            let splitedData = data
                .convertToString
                .split(separator: "\n").map {
                String($0)
            }
            print(splitedData)
          
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
                guard !line.isEmpty || !line.hasPrefix("#EXTM3U") else { return }
                
                if line.hasPrefix("#EXT-X-VERSION") {
                    list.version = Int(String(line.split(separator: ":")[1]))!
                } else if line.hasPrefix("#EXT-X-TARGETDURATION"){
                    list.targetDuration = Int(String(line.split(separator: ":")[1]))!
                } else if line.hasPrefix("#EXTINF") {
                    hasStreamInfo = true
                    let mediaSegment = MediaSegment()
                    let value = String(line.split(separator: ":")[1])
                    mediaSegment.duration = Float(value)
                    currentMediaSegment = mediaSegment
                } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE") {
                    // URI - must be
                } else{
                    //TODO: process another tag
                }
            }
           
        }.resume()
    }
}
