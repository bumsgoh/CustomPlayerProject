//
//  MPEG4.swift
//  CustomPlayer
//
//  Created by USER on 08/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

class Mpeg4File: Playable {
    
    private var videoTrackDecoder: TrackDecodable!
    private var audioTrackDecoder: TrackDecodable!
    private var mediaFileReader: MediaFileReadable!
    
    var videoData: [CMSampleBuffer] = [] {
        didSet {
            self.status = .prepared
        }
    }
    
    var audioData: [Data] = [] {
        didSet {
            self.status = .prepared
        }
    }
    
    private(set) var timescale: Int = 0
    private(set) var isPlayable: Bool = false
    private(set) var status: MediaStatus = .paused
    private(set) var tracks: [Track] = []
    
    private let jobQueue: DispatchQueue = DispatchQueue(label: "jobQueue")
    
    required init(url: URL) {
        guard let fileReader: FileStreamReadable = FileReader(url: url) else {
            assertionFailure("Failed to make file")
            return
        }
        self.mediaFileReader = Mpeg4FileReader(fileReader: fileReader)
        self.mediaFileReader.decodeMediaData()
        self.fetchTracks()
            self.trackDecode()
    
        
    }
    
    private func fetchTracks() {
      //  jobQueue.sync { [weak self] in
        
            self.status = .making
            self.tracks = self.mediaFileReader.makeTracks()
            self.timescale = self.tracks[0].timescale
       // }
    }
    
 

    
    private func trackDecode() {
        
        for track in tracks {
            
            var frames: [[UInt8]] = []
            var presentationTimestamp: [Int] = []
            
                for sample in track.samples {
                    mediaFileReader.fileReader.seek(offset: UInt64(sample.offset))
                    mediaFileReader.fileReader.read(length: sample.size) { (data) in
                
                        frames.append(Array(data))
                    }
                    presentationTimestamp = track.samples.map {
                        $0.startTime
                    }
                }
            
            
            switch track.mediaType {
            case .audio:
                self.audioTrackDecoder = AudioTrackDecoder(track: track,
                                                           samples: frames,
                                                           presentationTimestamp: presentationTimestamp)
                audioTrackDecoder.audioDelegate = self
             //   audioTrackDecoder.decodeTrack(samples: frames)
            case .video:
                print("dd")
             //   videoTrackDecoder = VideoTrackDecoder(track: track, dataPackage: DataPackage)
               // videoTrackDecoder.videoDelegate = self
               // videoTrackDecoder.decodeTrack(samples: frames)
            case .unknown:
                assertionFailure("player init failed")
            }
        }
    }
}

extension Mpeg4File: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: CMSampleBuffer) {
       // self.videoData = buffers
    }
}

extension Mpeg4File: MultiMediaAudioTypeDecoderDelegate {
    func prepareToPlay(with data: CMSampleBuffer) {
        
    }
    
    func prepareToPlay(with data: Data) {
        
    }
    
    func prepareToPlay(with data: [Data]) {
        self.audioData = data
    }
}
