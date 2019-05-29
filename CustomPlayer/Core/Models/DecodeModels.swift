//
//  Models.swift
//  CustomPlayer
//
//  Created by USER on 03/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

enum FileContainerType {
    case mp4
}

enum MediaType {
    case video
    case audio
    case unknown
}


class TrackItem {
    var sampleDuration: Int = 0
    var startTime: Int = 0
    var size: Int = 0
}

class Track {
    
    var mediaType: MediaType
    var chunks: [Chunk] = []
    var samples: [Sample] = []
    var duration: Int = 0
    var timescale: Int = 0
    var width: Int = 0
    var height: Int = 0
    
    
    var sequenceParameterSet: Data = Data()
    var sequenceParameters: [Data] = []
    
    var pictureParameterSet: Data = Data()
    var pictureParameters: [Data] = []
    
    var numberOfChannels: Int = 0
    var sampleRate: Int = 0
    
    init(type: MediaType) {
        self.mediaType = type
    }
    
}
