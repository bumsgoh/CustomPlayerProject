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
    let opQueue = OperationQueue()
    private var buffer: [CMSampleBuffer] = []
    private let decodeQueue: DispatchQueue = DispatchQueue(label: "com.decodeQeue")
    private let fetchingQueue: DispatchQueue = DispatchQueue(label: "com.fetchAndDecodeQueue")
    private let jobQueue: DispatchQueue = DispatchQueue(label: "decodeQueue")
    private let lockQueue: DispatchQueue = DispatchQueue(label: "com.lockQueue", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    private let isFileBasedPlayer: Bool
    private let url: URL
    private let httpConnection: HTTPConnetion
   
    private let tsLoader: TSLoader
    private var h264Decoder: H264Decoder = H264Decoder()
    var playContext = 1
    
    let semaphore = DispatchSemaphore(value: 1)
    private var currentPlayingItemIndex: ListIndex?
    private var state: MediaStatus = .stopped
    private var audioDecoder: AudioTrackDecodable?
    private var videoDecoder: VideoTrackDecodable?
    private var audioPlayer: AudioPlayer = AudioPlayer()
    
    @objc dynamic var isPlayable: Bool = false {
        didSet {
            if isPlayable {
                if !started {
                    queue.startRunning()
                    audioPlayer.playIfNeeded()
                    started = true
                }
            } else {
                
            }
        }
    }
    private var started = false
    private var isVideoReady: Bool = false
    private var isAudioReady: Bool = false
    
    private var masterPlaylist: MasterPlaylist?
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    var totalDuration = 0
    var volume: Float {
        get {
            return audioPlayer.volume
        }
        
        set {
            audioPlayer.volume = newValue
        }
    }
    
    weak var delegate: VideoQueueDelegate?
    
    private lazy var taskManager: TaskManager = {
        let manager = TaskManager()
      //  manager.delegate = self
        return manager
    }()
    
   
   
    private lazy var queue: DisplayLinkedQueue = {
        let queue: DisplayLinkedQueue = DisplayLinkedQueue()
        queue.delegate = self
        return queue
    }()
  
    init(url: URL) {
        self.httpConnection = HTTPConnetion()
        self.url = url
        self.tsLoader = TSLoader(url: url)
        if url.isFileURL {
            self.isFileBasedPlayer = true
        } else {
            self.isFileBasedPlayer = false
        }
        super.init()
        setObservers()
    }
    
    deinit {
        queue.removeObserver(self, forKeyPath: "isReady")
        queue.removeObserver(self, forKeyPath: "isBufferFull")
        audioPlayer.removeObserver(self, forKeyPath: "isReady")
    }
    
    func setObservers() {
        queue.addObserver(self, forKeyPath: "isReady", options: [.new, .old], context: &playContext)
        queue.addObserver(self, forKeyPath: "isBufferFull", options: [.new, .old], context: &playContext)
        audioPlayer.addObserver(self, forKeyPath: "isReady", options: [.new, .old], context: &playContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        
        guard context == &playContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(DisplayLinkedQueue.isBufferFull) {
            guard let oldValue = change?[.oldKey] as? Bool,
                let newValue = change?[.newKey] as? Bool else { return }
            if oldValue != newValue {
                if newValue {
                    decodeQueue.suspend()
                 //   self.h264Decoder.taskManager.pauseTask()
                    //self.fetchingQueue.suspend()
                //     print(self.h264Decoder.taskManager.queue.operations.count)
                 //   print("stop")
                   
                   
                } else {
                  decodeQueue.resume()
                 //   self.h264Decoder.taskManager.resumeTask()
                   // print(self.h264Decoder.taskManager.queue.operations.count)
                //    print("resume")
                   // self.fetchingQueue.resume()
                  
                }
            }
        }
        
        if keyPath == #keyPath(DisplayLinkedQueue.isReady) {
            guard let oldValue = change?[.oldKey] as? Bool,
                let newValue = change?[.newKey] as? Bool else { return }
            if oldValue != newValue {
                if newValue {
                    isVideoReady = true
                } else {
                    isVideoReady = false
                }
            }
        }
        
        if keyPath == #keyPath(AudioPlayer.isReady) {
            guard let oldValue = change?[.oldKey] as? Bool,
                let newValue = change?[.newKey] as? Bool else { return }
            if oldValue != newValue {
                if newValue {
                    isAudioReady = true
                } else {
                    isAudioReady = false
                }
            }
        }
        
        isPlayable =  isVideoReady && isAudioReady
//        if isPlayable { queue.startRunning() }
    }
    
    func loadPlayerAsynchronously(completion: @escaping (Result<Bool, Error>) -> Void) {
      //  jobQueue.async { [weak self] in
          //  guard let self = self else { return }
            if self.isFileBasedPlayer {
                guard let fileReader = FileReader(url: self.url) else { return }
                let mp4Parser = Mpeg4Parser(fileReader: fileReader)
                
                mp4Parser.parse() { [weak self] (result) in
                    guard let self = self else { return }
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let streams):
                        var videoDataArray = [UInt8]()
                        var videoTimings = [CMSampleTimingInfo]()
                        
                        streams.forEach {
                            switch $0.type {
                            case .video:
                                videoDataArray = $0.actualData
                                videoTimings = zip($0.pts, $0.dts).map {
                                    CMSampleTimingInfo(pts: Int64($0.0), dts: Int64($0.1), fps: 24)
                                }
                            case .audio:
                                break
                            //    print("d")
                             ///   self.prepareToPlay(with: Data($0.actualData))
                                self.isAudioReady = true
                            case .unknown:
                                return
                            }
                        }
                        self.h264Decoder.videoDecoderDelegate = self
                        
                        let metaData =  mp4Parser.fetchMetaData()
                        self.totalDuration = Int(metaData.totalDuration)
                        let parser = NALParser(sps: metaData.sequenceParameters.toUInt8Array,
                                               pps: metaData.pictureParameters.toUInt8Array)
                        
                        let nalus = parser.parse(frames: videoDataArray,
                                                type: .avcc,
                                                sizeArray: metaData.sampleSizeArray)
                        var count = 0
                        for nal in nalus {
                            var item: DispatchWorkItem?
                                if nal.type == .idr || nal.type == .slice {
                                    item = DispatchWorkItem {
                                        self.h264Decoder.decode(nal: nal, pts: videoTimings[count])
                                    }
                                    
                                    count += 1
                                    if count >= videoTimings.count - 1 { break }
                                } else {
                                    item = DispatchWorkItem {
                                        self.h264Decoder.decode(nal: nal)
                                    }
                                }
                            
                            self.decodeQueue.sync(execute: item!)
                        }
                        completion(.success(true))
                    }
                }
            } else {
                self.totalDuration = 5960 * 63
           
                self.h264Decoder.videoDecoderDelegate = self
                
                self.tsLoader.initializeLoader {
                   
                   self.requestNextTsItem()
//                        while true {
//                          // self.fetchingQueue.sync {
//                            let hasMore =
//                            if !hasMore { return }
//                       // }
//                    }
                    
                     completion(.success(true))
                }
                
                  //  self.requestNextTsItem()
                
                
          //  }
        }
    }
    
    private func requestNextTsItem() -> Bool {
     
        let isSuccess = tsLoader.fetchTsStream { [weak self] (result) in
    
            switch result {
            case .failure:
          
                return
                
            case .success(let tsStreams):
        
                self?.processStream(tsStreams)
            }
        }
        return isSuccess
    }
    
    private func processStream(_ streams: [DataStream]) {
   
        streams.forEach {
            switch $0.type {
            case .video:
               let timings = zip($0.pts, $0.dts).map {
                    CMSampleTimingInfo(pts: Int64($0.0),
                                       dts: Int64($0.1),
                                       fps: 24)
               }
               
               let parser = NALParser()
               let nalus = parser.parse(frames: $0.actualData,
                                        type: .annexB)
//               var num = 0
//               for nal in nalus {
//                if nal.type != .aud || nal.type != .unspecified { num += 1 }
//                print("no.\(num) \(nal)")
//                print()
//               }
               
               var count = 0
               var currentSlicePayload: [UInt8] = []
               var leadingFlag = false
//               for nal in nalus {
//                if nal.type == .unspecified {continue}
//                var item: DispatchWorkItem?
//                if nal.type == .idr || nal.type == .slice {
////                    if leadingFlag {
////                         currentSlicePayload.append(contentsOf: nal.payload)
////                        leadingFlag = false
////                    } else {
////                        currentSlicePayload.append(contentsOf: nal.payload[4...])
////                    }
////
////                   continue
//                    item = DispatchWorkItem {
//                         self.h264Decoder.decode(nal: nal, pts: timings[count])
//                    }
//                      count += 1
//
//                } else if nal.type == .aud {
////                    leadingFlag = true
////                    if !currentSlicePayload.isEmpty {
////                        count += 1
////                        if count >= timings.count - 1 { break }
////
////                        let mergedNAL = NALUnit(type: .idr, payload: currentSlicePayload)
////                        item = DispatchWorkItem {
////                            self.h264Decoder.decode(nal: mergedNAL, pts: timings[count])
////                        }
////                        currentSlicePayload = []
////                    } else {
////                           continue
////                    }
//
//                    continue
//
//                } else {
//                    item = DispatchWorkItem {
//                        self.h264Decoder.decode(nal: nal)
//                    }
//                }
//
//                self.decodeQueue.sync(execute: item!)
//               }

               for nal in nalus {
                var item: DispatchWorkItem?
                if nal.type == .idr || nal.type == .slice {
                    item = DispatchWorkItem {
                        self.h264Decoder.decode(nal: nal, pts: timings[count])
                    }
                    
                    count += 1
                    if count >= timings.count - 1 { break }
                } else {
                    item = DispatchWorkItem {
                        self.h264Decoder.decode(nal: nal)
                    }
                }
                
                self.decodeQueue.sync(execute: item!)
                
                usleep(10000)
                }
            case .audio:
                break
                 self.prepareToPlay(with: Data($0.actualData))
                
            case .unknown:
                return
            }
        }
    }

    func play() {
        
        if isPlayable {
            started = true
            queue.startRunning()
            audioPlayer.playIfNeeded()
        } else {
            started = false
        }
        
    }
    
    func pause() {
        queue.stopRunning()
        audioPlayer.pause()
        started = false
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
       // audioPlayer.parseDeliveredData(data: dataFromDecoder)
    }
}

extension MoviePlayer: MultiMediaAudioTypeDecoderDelegate {
    func prepareToPlay(with data: Data) {
        audioPlayer.parseDeliveredData(data: data)
    }
    
}

extension MoviePlayer: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: CMSampleBuffer) {
        //delegate?.displayQueue(with: buffers)
         queue.enqueue(buffers)
       
    }
    
}

protocol VideoQueueDelegate: class {
     func displayQueue(with buffers: CMSampleBuffer)
}


extension MoviePlayer: DisplayLinkedQueueDelegate {
    // MARK: DisplayLinkedQueue
    func queue(_ buffer: CMSampleBuffer) {

        delegate?.displayQueue(with: buffer)

    }
}

class ListIndex {
    var gear: Int = 0
    var index: Int = 0
    
    init(gear: Int, index: Int) {
        self.gear = gear
        self.index = index
    }
}

