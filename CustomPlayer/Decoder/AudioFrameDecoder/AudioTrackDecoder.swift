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
    
    private(set) var track: Track

    private var derivedData: Data = Data()
    var dataPackage: DataPackage
    
    private var isPrepared: Bool = false
    

    init(track: Track, dataPackage: DataPackage) {
        self.track = track
        self.dataPackage = dataPackage
    }
    
    func decodeTrack(timeScale: Int)  {
        var mergedData = Data()
        dataPackage.dataStorage.forEach {
            var mutableData = $0
           mergedData.append(mutableData.addADTS)
        }
        audioDelegate?.prepareToPlay(with: mergedData)
    }
}
