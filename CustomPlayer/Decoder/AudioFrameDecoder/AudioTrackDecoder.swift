//
//  AudioFrameDecoder.swift
//  H264Player
//
//  Created by USER on 02/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import CoreMedia
import AudioToolbox

class AudioTrackDecoder: TrackDecodable {
   var audioFileStreamID: AudioFileStreamID? = nil
    var videoDelegate: MultiMediaVideoTypeDecoderDelegate? = nil
    
    var audioDelegate: MultiMediaAudioTypeDecoderDelegate?
    
    private(set) var presentationTimestamp: [Int]
    private(set) var track: Track
    private(set) var samples: [[UInt8]]
    private var derivedData: Data = Data()
    
    private var isPrepared: Bool = false
    

    init(track: Track, samples: [[UInt8]], presentationTimestamp: [Int]) {
        self.track = track
        self.samples = samples
        self.presentationTimestamp = presentationTimestamp
    }
    
    func decodeTrack(samples frames: [[UInt8]], pts: [Int])  {
        var mergedData = Data()
        samples.forEach {
           mergedData.append($0.tohexNumbers
                .mergeToString
                .convertHexStringToData
                .addADTS
            )
        }
        audioDelegate?.prepareToPlay(with: mergedData)
    }
}
