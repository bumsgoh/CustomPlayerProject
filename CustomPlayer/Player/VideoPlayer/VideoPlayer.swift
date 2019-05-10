//
//  VideoPlayer.swift
//  CustomPlayer
//
//  Created by USER on 10/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

class VideoPlayer: NSObject {
    var state: MediaStatus = .stopped
    let decoder: TrackDecodable
    let track: Track
    let dataPackage: DataPackage
    
    init(decoder: TrackDecodable,
         track: Track,
         dataPackage: DataPackage) {
        self.decoder = decoder
        self.track = track
        self.dataPackage = dataPackage
    }
    
    func prepareToPlay() {
        decoder.decodeTrack(timeScale: track.timescale)
    }
    
    func play() {
        
    
    }
    
    func pause() {

    }
}

extension VideoPlayer: MultiMediaDecoderDelegate {
    func prepareToPlay<T>(with mediaData: T) {
        guard let sampleBuffer: CMSampleBuffer = mediaData as? CMSampleBuffer else {
            return
        }
        
    }
    
    func prepareToPlay(with mediaData: CMSampleBuffer) {
        
    }
}
