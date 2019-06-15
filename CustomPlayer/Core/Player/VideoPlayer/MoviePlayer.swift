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
    private let processQueue: DispatchQueue = DispatchQueue(label: "processQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    private let fetchingQueue: DispatchQueue = DispatchQueue(label: "com.fetchQueue")
    private let isFileBasedPlayer: Bool
    private let url: URL
    private let httpConnection: HTTPConnetion
   
    private let tsLoader: TSLoader
    private var h264Decoder: H264Decoder = H264Decoder()
    var playContext = 1
    
    var interruptHandler: InterruptHandler?
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
                    queue.start()
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
        
        setInterruptHandler()
        setObservers()
    }
    
    deinit {
        queue.removeObserver(self, forKeyPath: "isReady")
        queue.removeObserver(self, forKeyPath: "isBufferFull")
        audioPlayer.removeObserver(self, forKeyPath: "isAudioReady")
        interruptHandler = nil
    }
    
    func setObservers() {
        queue.addObserver(self, forKeyPath: "isReady", options: [.new, .old], context: &playContext)
        queue.addObserver(self, forKeyPath: "isBufferFull", options: [.new, .old], context: &playContext)
        audioPlayer.addObserver(self, forKeyPath: "isAudioReady", options: [.new, .old], context: &playContext)
    }
    
    func setInterruptHandler() {
        self.interruptHandler = { (interrupt) in
            switch interrupt {
            case .multiTrackRequest(let trackNumber):
                //tsLoader.
               // print(trackNumber)
                self.fetchingQueue.suspend()
                self.tsLoader.currentPlayingItemIndex?.index -= 1
                self.tsLoader.currentPlayingItemIndex?.gear = trackNumber
                self.fetchingQueue.resume()
              //  self.taskManager.pauseTask()
            case .seek(let time):
                print(time)
            }
        }
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
                    taskManager.pauseTask()
                 //   self.h264Decoder.taskManager.pauseTask()
                //   self.fetchingQueue.suspend()
                //     print(self.h264Decoder.taskManager.queue.operations.count)
                 //   print("stop")
                   
                   
                } else {
                  taskManager.resumeTask()
                 //   self.h264Decoder.taskManager.resumeTask()
                   // print(self.h264Decoder.taskManager.queue.operations.count)
                //    print("resume")
               //     self.fetchingQueue.resume()
                  
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
        
        if keyPath == #keyPath(AudioPlayer.isAudioReady) {
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
        print("vide\(isVideoReady)")
        print("aud\(isAudioReady)")
        print(isPlayable)
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
                            
                            self.taskManager.add(task: item!)
                        }
                        completion(.success(true))
                    }
                }
            } else {
                self.totalDuration = 5960 * 63
           
                self.h264Decoder.videoDecoderDelegate = self
                
                self.tsLoader.initializeLoader {
                   
                   self.startStreaming()
//                        while true {
//                          // self.fetchingQueue.sync {
//                            let hasMore =
//                            if !hasMore { return }
//                       // }
//                    }
                    
                     completion(.success(true))
                }
        }
    }
    
    private func startStreaming() {
        
        fetchingQueue.async {
            let semaphore = DispatchSemaphore(value: 1)
            var hasMore = true
            while hasMore {
                semaphore.wait()
               hasMore = self.tsLoader.fetchTsStream { [weak self] (result) in
                
                    switch result {
                    case .failure:
                         semaphore.signal()
                        return
                        
                    case .success(let tsStreams):
                       
                        self?.processStream(tsStreams) {
                             semaphore.signal()
                        }
                    }
                }
            }
        }
    }
    
    private func processStream(_ streams: [DataStream], completion: @escaping () -> Void) {
        
      //  let sem = DispatchSemaphore(value: 0)
        for stream in streams {
            switch stream.type {
                
            case .video:
                //DispatchQueue.global().async {
                    
                let timings = zip(stream.pts, stream.dts).map {
                    
                    CMSampleTimingInfo(pts: Int64($0.0),
                                       dts: Int64($0.1),
                                       fps: 24)
                }
                
                let parser = NALParser()
                let nalus = parser.parse(frames: stream.actualData,
                                         type: .annexB)
                
                var count = 0
                
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
                    
                    
                    if !self.taskManager.add(task: item!) {
                        self.h264Decoder.multiTrackThresHoldPts = timings[count].presentationTimeStamp
                        break
                    }
              //      }
                   // sem.signal()
                    
                }
            case .audio:
                isAudioReady = true
               
                 //
                self.prepareToPlay(with: Data(stream.actualData))
                
            case .unknown:
                return
            }
           
        }
       
       // sem.wait()
        completion()
//        streams.forEach {
//            print("dddd")
//
//
//
//        }
    }

    func play() {
        
        if isPlayable {
            started = true
            queue.start()
            audioPlayer.playIfNeeded()
        } else {
            started = false
        }
        
    }
    
    func pause() {
        queue.pause()
        audioPlayer.pause()
        started = false
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
       // audioPlayer.parseDeliveredData(data: dataFromDecoder)
    }
    
    
    func interruptCall(with interrupt: Interrupt) {
        guard let handler = interruptHandler else { return }
        handler(interrupt)
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

