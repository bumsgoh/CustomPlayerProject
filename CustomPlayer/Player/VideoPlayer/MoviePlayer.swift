//
//  VideoPlayer.swift
//  CustomPlayer
//
//  Created by USER on 10/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

class MoviePlayer: NSObject {
    typealias T = CMSampleBuffer
    var state: MediaStatus = .stopped
    let jobQueue: DispatchQueue = DispatchQueue(label: "decodeQueue")
    let isFileBasedPlayer: Bool
    let url: URL
    weak var delegate: VideoQueueDelegate?
    let audioQueue = DispatchQueue(label: "audioPlayQueue")
    let syncSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    private var audioDecoder: AudioTrackDecodable?
    private var videoDecoder: VideoTrackDecodable?

    var isPlayable: Bool {
        return isVideoReady && isAudioReady
    }
    
    private var isVideoReady: Bool = false
    private var isAudioReady: Bool = false
    
    init(url: URL) {
        self.url = url
        if url.isFileURL {
            self.isFileBasedPlayer = true
        } else {
            self.isFileBasedPlayer = false
        }
    }
    
    func prepareToPlay() {
        jobQueue.sync { [weak self] in
            guard let self = self else { return }
            
            guard let fileReader = FileReader(url: self.url) else { return }
            let mediaFileReader = Mpeg4Parser(fileReader: fileReader)
            
            mediaFileReader.decodeMediaData()
            let tracks = mediaFileReader.makeTracks()
            
            for track in tracks {
                var sizeArray: [Int] = []
                var rawFrames: [Data] = []
                var presentationTimestamp: [Int] = []
                
                for sample in track.samples {
                    
                    mediaFileReader.fileReader.seek(offset: UInt64(sample.offset))
                    mediaFileReader.fileReader.read(length: sample.size) { (data) in
                        rawFrames.append(data)
                        sizeArray.append(data.count)
                    }
                }
                presentationTimestamp = track.samples.map {
                    $0.startTime
                }
                let dataPackage = DataPackage(presentationTimestamp: presentationTimestamp,
                                              dataStorage: rawFrames)
                
                
                switch track.mediaType {
                case .audio:
                    self.audioDecoder = AAC_ADTSDecoder(track: track, dataPackage: dataPackage)
                    self.audioDecoder?.audioDelegate = self
                    self.audioDecoder?.decodeTrack(timeScale: track.timescale)
                case .video:
                    self.videoDecoder  = AvccDecoder(track: track, dataPackage: dataPackage)
                    self.videoDecoder?.videoDelegate = self
                    self.videoDecoder?.decodeTrack(timeScale: track.timescale)
                case .unknown:
                    assertionFailure("player init failed")
                }
            }
        }
    }
    
    func play() {
        guard state == .prepared else { return }
       // syncSemaphore.signal()
    }
    
    func pause() {

    }
}

extension MoviePlayer: MultiMediaAudioTypeDecoderDelegate {
    func prepareToPlay(with data: Data) {
        isAudioReady = true
        let audioPlayer = AudioPlayer(data: data)
        audioQueue.async {
          //  self.syncSemaphore.wait()
            audioPlayer.play()
          //  self.syncSemaphore.signal()
        }
    }
    
   
}

extension MoviePlayer: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: CMSampleBuffer) {
        isVideoReady = true
      //   self.syncSemaphore.wait()
        delegate?.displayQueue(with: buffers)
    }
}

protocol VideoQueueDelegate: class {
     func displayQueue(with buffers: CMSampleBuffer)
}
