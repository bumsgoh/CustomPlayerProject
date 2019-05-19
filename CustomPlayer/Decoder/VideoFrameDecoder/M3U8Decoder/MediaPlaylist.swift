//
//  MediaPlaylist.swift
//  CustomPlayer
//
//  Created by bumslap on 19/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class MediaPlaylist {
    var masterPlaylist: MasterPlaylist?
    
    var programId: Int = 0
    var bandwidth: Int = 0
    var frameRate: Float = 0
    var resolution: String = ""
    var path: String?
    var version: Int?
    var targetDuration: Int?
    var mediaSequence: Int?
    
    var mediaSegments = [MediaSegment]()
    
    func parseMediaInfo(target: String) {
        let data = target.split(separator: ",")
        for value in data {
            if value.hasPrefix("BANDWIDTH") {
                guard let extractedValue = Int(String(value.split(separator: "=")[1])) else { break }
                bandwidth = extractedValue
            } else if value.hasPrefix("CODECS") {
               
            } else if value.hasPrefix("RESOLUTION") {
                resolution = String(value.split(separator: "=")[1])
            } else if value.hasPrefix("FRAME-RATE") {
                guard let extractedValue = Float(String(value.split(separator: "=")[1])) else { break }
                frameRate = extractedValue
            } else {
                
            }
        }
        
    }

}
extension MediaPlaylist: Comparable, Equatable {
    static func < (lhs: MediaPlaylist, rhs: MediaPlaylist) -> Bool {
        return lhs.bandwidth < rhs.bandwidth
    }
    
    static func == (lhs: MediaPlaylist, rhs: MediaPlaylist) -> Bool {
        return lhs.path == lhs.path
    }
    
    
}
