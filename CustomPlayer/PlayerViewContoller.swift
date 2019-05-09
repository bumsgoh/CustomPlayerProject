//
//  ViewController.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import UIKit
import VideoToolbox
import AVFoundation

class PlayerViewContoller: UIViewController {
    
    let serialQueue = DispatchQueue(label: "serial queue")
    var localBuffer: [CMSampleBuffer] = []
    var count = 0
    let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    var tracks: [Track] = []
    
    var audioTrackDecoder: TrackDecodable?
    var videoTrackDecoder: TrackDecodable?
   

    private let videoPlayerLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
       
        
        layer.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        return layer
    }()
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(#imageLiteral(resourceName: "play-button"), for: .normal)
        return button
    }()
    
    private let readButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(#imageLiteral(resourceName: "play-button"), for: .normal)
        button.tintColor = .red
        return button
    }()
    
    init() {
        //self.videoDecoder = videoDecoder
        //self.audioDecoder = audioDecoder
        super.init(nibName: nil, bundle: nil)
       
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //videoDecoder.layer = self.videoPlayerLayer
        
        setUpLayer()
        setUpViews()
       
        var controlTimebase: CMTimebase? = nil
        var clock: CMClock? = nil
       // var useHostClock: Bool = true
        
       
            clock = CMClockGetHostTimeClock()
       
        let status = CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: clock!, timebaseOut: &controlTimebase)
        
        
        if status != 0 {
            assertionFailure("fail to clock")
        }
        else {
            CMTimebaseSetRate(controlTimebase!, rate: 0.5);
            CMTimebaseSetTime(controlTimebase!, time: CMTime(value: 1, timescale: 5))
        }
        
        self.videoPlayerLayer.controlTimebase = controlTimebase
        

       
        
        //VideoTrackDecoder.delegate = self
        
      
        // Do any additional setup after loading the view.
    }

    private func setUpLayer() {
        view.layer.addSublayer(videoPlayerLayer)
    }
    
    private func setUpViews() {
        view.addSubview(playButton)
        view.addSubview(readButton)
        playButton.centerXAnchor.constraint(
            equalTo: view.centerXAnchor).isActive = true
        playButton.centerYAnchor.constraint(
            equalTo: view.centerYAnchor).isActive = true
        
        playButton.addTarget(self, action: #selector(playButtonDidTap),
                             for: .touchUpInside)
        
        readButton.centerXAnchor.constraint(
            equalTo: view.centerXAnchor).isActive = true
        readButton.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        
        readButton.addTarget(self, action: #selector(readButtonDidTap),
                             for: .touchUpInside)
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPlayerLayer.frame = CGRect(x: view.frame.origin.x / 2.0,
                                        y: view.center.y - view.frame.width * 0.25,
                                        width: view.frame.width,
                                        height: view.frame.width * 0.5)
    }
    
    @objc func playButtonDidTap() {
        playButton.isHidden = true
        
        guard let filePath =  Bundle.main.path(forResource: "you", ofType: "mp4") else { return }
        let url = URL(fileURLWithPath: filePath)
        let fileReader = FileReader(url: url)
        let mediaFileReader = Mpeg4FileReader(fileReader: fileReader!)
        
        mediaFileReader.decodeMediaData()
        tracks = mediaFileReader.makeTracks()
        
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
                audioTrackDecoder?.audioDelegate = self
                audioTrackDecoder?.decodeTrack()
            case .video:
                videoTrackDecoder = VideoTrackDecoder(track: track, samples: frames, presentationTimestamp: presentationTimestamp)
                videoTrackDecoder?.videoDelegate = self
                videoTrackDecoder?.decodeTrack()
            case .unknown:
                assertionFailure("player init failed")
            }
        }
        
      //  let videoDecoder = VideoTrackDecoder(track: <#T##Track#>, samples: <#T##[[UInt8]]#>, presentationTimestamp: <#T##[Int]#>)
        
//            let reader = FileReader(url: url)
//            let mediaReader = Mpeg4FileReader(fileReader: reader!)
//            mediaReader.decodeMediaData()
//            let tracks = mediaReader.makeTracks()
//
//          //  videoDecoder.track = tracks[0]
//
//            var frames: [[UInt8]] = []
//                    for sample in tracks[0].samples {
//                        mediaReader.fileReader.seek(offset: UInt64(sample.offset))
//                        mediaReader.fileReader.read(length: sample.size) { (data) in
//
//                            frames.append(Array(data))
//
//                        }
//                    }
//                    //videoDecoder.track = tracks[0]
//        let timingPts = tracks[0].samples.map {
//            $0.startTime
//        }
        
        
       // let mp4File = Mpeg4File(url: url)
        
      // videoDecoder.decodeTrack(samples: frames, pts: timingPts)
  
       /* videoPlayerLayer.requestMediaDataWhenReady(on: serialQueue, using: { [weak self] in
            guard let self = self else { return }
            while self.videoPlayerLayer.isReadyForMoreMediaData {
               // if let sample = mp4File.videoData.copyNextSample(){
       
                    self.videoPlayerLayer.enqueue(sample)
               
                } else {
                    self.videoPlayerLayer.stopRequestingMediaData()
                }
                
                
            }
        })*/
    
    }
    
    @objc func readButtonDidTap() {
      
        guard let filePath =  Bundle.main.path(forResource: "you", ofType: "mp4") else { return }
        let url = URL(fileURLWithPath: filePath)
        let reader = FileReader(url: url)
        let mediaReader = Mpeg4FileReader(fileReader: reader!)
        mediaReader.decodeMediaData()
        let tracks = mediaReader.makeTracks()
       // audioDecoder?.play()
        var frames: [[UInt8]] = []
        for sample in tracks[1].samples {
            //print(sample.offset)
            mediaReader.fileReader.seek(offset: UInt64(sample.offset))
           // print(sample.size)
            mediaReader.fileReader.read(length: sample.size) { (data) in

                frames.append(Array(data))

            }
        }
        
  

        //audioDecoder?.decodeTrack(samples: frames, pts: timingPts)
        
 
    }
    
    


}

extension PlayerViewContoller: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: [CMSampleBuffer]) {
        var mutableBuffer = buffers
        //self.semaphore.wait()
        videoPlayerLayer.requestMediaDataWhenReady(on: serialQueue, using: { [weak self] in
            guard let self = self else { return }
            
            while self.videoPlayerLayer.isReadyForMoreMediaData {
                if let sample = mutableBuffer.copyNextSample(){
                
                self.videoPlayerLayer.enqueue(sample)
                    
                
            } else {
                
                self.videoPlayerLayer.stopRequestingMediaData()
            }
            
            
        }
    })
    }
}

extension PlayerViewContoller: MultiMediaAudioTypeDecoderDelegate {
    func prepareToPlay(with data: Data) {
        guard let filePath =  Bundle.main.path(forResource: "ma", ofType: "mp4") else { return }
        let url = URL(fileURLWithPath: filePath)
        let avPlayer = AudioPlayer(url: url, data: data)
        DispatchQueue.global().async {
            avPlayer.play()
     //       self.semaphore.signal()
        }
    }
}
