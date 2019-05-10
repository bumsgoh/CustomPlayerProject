//
//  VideoDecoderDelegate.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

protocol MultiMediaVideoTypeDecoderDelegate: class {
     func prepareToDisplay(with buffers: CMSampleBuffer) 
}

protocol MultiMediaAudioTypeDecoderDelegate: class {
    func prepareToPlay(with data: Data)
}

protocol MultiMediaDecoderDelegate: class {
    func prepareToPlay<T>(with mediaData: T)
}
