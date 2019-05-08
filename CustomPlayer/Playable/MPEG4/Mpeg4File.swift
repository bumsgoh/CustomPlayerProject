//
//  MPEG4.swift
//  CustomPlayer
//
//  Created by USER on 08/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class Mpeg4File: Playable {
    private var videoTrackDecoder: TrackDecodable!
    private var audioTrackDecoder: TrackDecodable!
    private var mediaFileReader: MediaFileReadable!
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
    }
    
    convenience init() {
        self.init()
        self.mediaFileReader.decodeMediaData()
        self.fetchTracks() { [weak self] in
            guard let self = self else { return }
            
        }
    }
    
    private func fetchTracks(completion: @escaping () -> Void) {
        jobQueue.async { [weak self] in
            guard let self = self else { return }
            self.status = .making
            self.tracks = self.mediaFileReader.makeTracks()
            self.timescale = self.tracks[0].timescale
            
        }
    }
    
    private func trackDecoding() {
        
        for track in tracks {
            
            var frames: [[UInt8]] = []
            var presentationTime: [Int] = []
            
            for track in tracks {
                for sample in track.samples {
                    mediaFileReader.fileReader.seek(offset: UInt64(sample.offset))
                    mediaFileReader.fileReader.read(length: sample.size) { (data) in
                
                        frames.append(Array(data))
                    }
                    presentationTime = track.samples.map {
                        $0.startTime
                    }
                }
            }
            
            switch track.mediaType {
            case .audio:
                self.audioTrackDecoder = AudioTrackDecoder()
                audioTrackDecoder.decodeTrack(samples: frames, pts: presentationTime)
            case .video:
                self.videoTrackDecoder = VideoTrackDecoder(sps: track.sequenceParameters.toUInt8Array,
                                                           pps: track.pictureParams.toUInt8Array)
                videoTrackDecoder.decodeTrack(samples: frames, pts: presentationTime)
            case .unknown:
                assertionFailure("player init failed")
            }
        }
    }
}
