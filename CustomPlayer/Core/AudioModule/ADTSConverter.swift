//
//  AudioFrameDecoder.swift
//  H264Player
//
//  Created by USER on 02/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class ADTSConverter: AudioTrackDecodable {
    var videoDelegate: MultiMediaVideoTypeDecoderDelegate? = nil
    
    var audioDelegate: MultiMediaAudioTypeDecoderDelegate?
    
    var isAdts = true
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
            
            
            if isAdts{
                mergedData.append($0.addADTS)
                
            } else {
                mergedData.append($0)
            }
        }
        
        audioDelegate?.prepareToPlay(with: mergedData)
    }
    
    
}
