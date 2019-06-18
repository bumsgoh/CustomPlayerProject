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
    
    private let fetchOperationQueue: OperationQueue = OperationQueue()
    private let fetchingQueue: DispatchQueue = DispatchQueue(label: "com.fetchQueue")
    private let isFileBasedPlayer: Bool
    private let url: URL
    private let httpConnection: HTTPConnetion
    let interruptTaskManger = TaskManager()
    private let tsLoader: TSLoader
    private var h264Decoder: H264Decoder = H264Decoder()
    var playContext = 1
    
    var interruptHandler: InterruptHandler?
    let semaphore = DispatchSemaphore(value: 0)
    
    private var multiTrackStartPts: CMTimeValue = 0
    private var currentPlayingItemIndex: ListIndex?
    private var state: MediaStatus = .stopped
    private var audioDecoder: AudioTrackDecodable?
    private var videoDecoder: VideoTrackDecodable?
    private var audioPlayer: AudioPlayer = AudioPlayer()
    private var isInterrupted: Bool = false
    private var currentPlayingTSIndex = 0
    private var currentFps = 0
    
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
        return manager
    }()
    
    private lazy var nalProcessor: NALProcessor = {
        let processor = NALProcessor(taskManager: self.taskManager)
        processor.delegate = self
        return processor
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
            case .multiTrackRequest(let trackURL):
               // self.fetchingQueue.suspend()
              
                self.isInterrupted = true
                self.taskManager.interruptCall()
                self.tsLoader.load(with: trackURL, index: self.tsLoader.currentPlayingItemIndex!.index - 1) {
                 //   self.startStreaming()
                    
                    
                 //   self.fetchingQueue.resume()
                }
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
                    
                  //  interruptTaskManger.pauseTask()
                taskManager.pauseTask()
               //    self.fetchingQueue.suspend()
                //     print(self.h264Decoder.taskManager.queue.operations.count)
                    print("stop")
                   
                   
                } else {
                //  interruptTaskManger.resumeTask()
                taskManager.resumeTask()
                   // print(self.h264Decoder.taskManager.queue.operations.count)
                    print("resume")
               //    self.fetchingQueue.resume()
                  
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
                       // self.h264Decoder.videoDecoderDelegate = self
                        let metaData =  mp4Parser.fetchMetaData()
                        self.totalDuration = Int(metaData.totalDuration)
                        
                        var videoDataArray = [UInt8]()
                        var videoTimings = [CMSampleTimingInfo]()
                      
                        completion(.success(true))
                        streams.forEach {
                            switch $0.type {
                            case .video:
                                videoDataArray = $0.actualData
                                videoTimings = zip($0.pts, $0.dts).map {
                                    CMSampleTimingInfo(pts: Int64($0.0), dts: Int64($0.1), fps: 24)
                                }
                            case .audio:
                        
                                self.prepareToPlay(with: Data($0.actualData))

                            case .unknown:
                                return
                            }
                        }
                  
                        self.nalProcessor.setMetaData(sps: metaData.sequenceParameters.toUInt8Array, pps: metaData.pictureParameters.toUInt8Array)
                     
                        self.nalProcessor.process(frames: videoDataArray,
                                                 type: .avcc, pts: videoTimings,
                                                 sizeArray: metaData.sampleSizeArray)
                         completion(.success(true))
                       
                    }
                }
            } else {
                self.totalDuration = 5960 * 63
           
              //  self.h264Decoder.videoDecoderDelegate = self
                
                self.tsLoader.load(with: url) {
                   
                   self.startStreaming()
                    
                     completion(.success(true))
                }
        }
    }
    
    private func startStreaming() {
        
        fetchingQueue.async {
       
            let semaphore = DispatchSemaphore(value: 1)
            var hasMore = true
            while hasMore {
                
                if self.isInterrupted {
                 //  self.semaphore.wait()
                }
             
                semaphore.wait()
               hasMore = self.tsLoader.fetchTsStream {(result) in
                
                    switch result {
                    case .failure:
                         semaphore.signal()
                        return
                        
                    case .success(let tsStreams):
                        
                            self.processStream(tsStreams) {
                               
                            
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
                let timings = zip(stream.pts, stream.dts).map {
                    
                    CMSampleTimingInfo(pts: Int64($0.0),
                                       dts: Int64($0.1),
                                       fps: 24)
                }
            
                if self.isInterrupted {
                
                  //  taskManager.cancelAllItems()
                    taskManager.reset()
                    nalProcessor.reset()
                    
                    let isbad = nalProcessor.process(frames: stream.actualData,
                                              type: .annexB, pts: timings)
                   
                    self.isInterrupted = false
                   
                  
                   // nalProcessor.reset()
                    print("reut")
                 
                 //   self.nalProcessor.reset()
                } else {
//                    let manager = TaskManager()
                    let processor = NALProcessor(taskManager: taskManager)
                    processor.delegate = self

                 //   interruptTaskManger.reset()
                    
                    let canMoreProcess = processor.process(frames: stream.actualData,
                                                              type: .annexB,
                                                              pts: timings)
                    print("can more\(canMoreProcess)")
                    if !canMoreProcess {
                        
                        nalProcessor.setMultiTrackStartPts(value: processor.stoppedPts)
                        print("can pts\(processor.stoppedPts)")
                    }
                    
                }
   

             
                
            case .audio:
                if self.isInterrupted { break }
                self.prepareToPlay(with: Data(stream.actualData))
                
            case .unknown:
                return
            }
           
        }
       

        print("done")
         completion()

    }

    func resume() {
        
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
        started = true
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

