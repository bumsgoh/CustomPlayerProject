
//
//  MediaMixer.swift
//  CustomPlayer
//
//  Created by bumslap on 11/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class MediaMixer: NSObject {
    let videoPlayer: MediaPlayable
    let audioPlayer: MediaPlayable
    
    init(videoPlayer: MediaPlayable, audioPlayer: MediaPlayable) {
        self.videoPlayer = videoPlayer
        self.audioPlayer = audioPlayer
    }
    
    func start() {
        
    }
    
    func pause() {
        
    }
    
    func stop() {
        
    }
    
}
