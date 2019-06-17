//
//  M3U8Decoder.swift
//  CustomPlayer
//
//  Created by bumslap on 19/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class M3U8Parser {
    
    
    private let httpConnection: HTTPConnetion
    
    init () {
  
        self.httpConnection = HTTPConnetion()
    }
    
    func extractBaseURL(from url: URL) -> String {
        var splitedURL = url.absoluteString.split(separator: "?")[0].split(separator: "/")
        splitedURL.remove(at: (splitedURL.count - 1))
        splitedURL[0].append(contentsOf: "/")
        let newURL = String(splitedURL.joined(separator: "/"))
        return newURL
    }
    
    func parseMasterPlaylist(with url: URL, completion: @escaping (Result<MasterPlaylist,Error>, URLResponse?) -> Void) {
        
        httpConnection.request(url: url) { (result, response) in
            switch result {
            case .failure:
                completion(.failure(APIError.requestFailed), nil)
                return
            case .success(let data):
                let splitedData = data.convertToString
                    .split(separator: "\n")
                    .map {
                        String($0)
                    }
                
                let masterPlaylist = MasterPlaylist()
                var hasStreamInfo = false
                var currentMedialist: MediaPlaylist?
                
                for line in splitedData {
                    if hasStreamInfo {
                        guard let mediaPlaylist = currentMedialist else { return }
                        if line.hasPrefix("http") {
                            mediaPlaylist.path = line //+ "?__gda__=1560759141_52fdc5cdc1a6487ea4c184a716c76076"
                        } else {
                            mediaPlaylist.path = self.extractBaseURL(from: url) + "/\(line)"
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
                completion(.success(masterPlaylist), response)
            }
        }
    }
    
    func parseMediaPlaylist(list: MediaPlaylist, completion: @escaping () -> Void) {
        guard let stringURL = list.path, let url = URL(string: stringURL) else { return }
        httpConnection.request(url: url) { (result, response) in
            switch result {
            case .failure:
                assertionFailure("fail to make mediaPlaylist")
                
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
                        list.videoMediaSegments.append(mediaSegment)
                     
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
                list.isParsed = true
                completion() 
            }
        }
    }
}
