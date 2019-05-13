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
    let lockQueue: DispatchQueue = DispatchQueue(label: "com.lockQueue", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    let isFileBasedPlayer: Bool
    let url: URL
    var videoPacketBuffer: [CMSampleBuffer] = []
    var audioPacketBuffer: Data = Data()
    weak var delegate: VideoQueueDelegate?
    let audioQueue = DispatchQueue(label: "audioPlayQueue")
    let syncSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    private var audioDecoder: AudioTrackDecodable?
    private var videoDecoder: VideoTrackDecodable?
    var audioPlayer: AudioPlayer?
     private var isReady: Bool = false
    var bufferTime: TimeInterval = 10 // sec
    private(set) var duration: TimeInterval = 0
    var playing = false
    var isThumNailSet: Bool = false
    var isPlayable: Bool {
        return isVideoReady && isAudioReady
    }
    var totalDuration = 0
    lazy var queue: DisplayLinkedQueue = {
        let queue: DisplayLinkedQueue = DisplayLinkedQueue()
        queue.delegate = self
        return queue
    }()
    var dataFromDecoder = Data()
    
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
        jobQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let fileReader = FileReader(url: self.url) else { return }
            let mediaFileReader = Mpeg4Parser(fileReader: fileReader)
            
            mediaFileReader.decodeMediaData()
            let tracks = mediaFileReader.makeTracks()
            self.totalDuration = tracks[0].duration
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
                    self.videoDecoder?.decodeTrack(timeScale: 30000)
                case .unknown:
                    assertionFailure("player init failed")
                }
            }
        }
    }
    
    func play() {
        queue.startRunning()
        audioPlayer?.playIfNeeded()
    }
    
    func pause() {
        queue.stopRunning()
        audioPlayer?.pause()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.seek(to: time)
        audioPlayer?.parseDeliveredData(data: dataFromDecoder)
    }
}

extension MoviePlayer: MultiMediaAudioTypeDecoderDelegate {
    func prepareToPlay(with data: Data) {
        isAudioReady = true
    audioPlayer = AudioPlayer()
        dataFromDecoder = data
        audioPlayer?.parseDeliveredData(data: data)
    }
}

extension MoviePlayer: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: CMSampleBuffer) {

         queue.enqueue(buffers)
    }
    
}

protocol VideoQueueDelegate: class {
     func displayQueue(with buffers: CMSampleBuffer)
}


extension MoviePlayer: DisplayLinkedQueueDelegate {
    // MARK: DisplayLinkedQueue
    func queue(_ buffer: CMSampleBuffer) {
        if playing == false {
            playing = true
            self.audioPlayer?.playIfNeeded()
        }
        delegate?.displayQueue(with: buffer)
    }
}
