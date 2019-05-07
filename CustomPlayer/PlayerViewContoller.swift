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
    let semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    private var videoDecoder: TrackDecodable = VideoTrackDecoder(videoFrameReader: VideoFrameReader())
    private var audioDecoder: TrackDecodable?
    let audioRenderer = AVSampleBufferAudioRenderer()
    let synchronizer: AVSynchronizedLayer = AVSynchronizedLayer()
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
            CMTimebaseSetRate(controlTimebase!, rate: 1.0);
            CMTimebaseSetTime(controlTimebase!, time: CMTimeMakeWithSeconds(CACurrentMediaTime(), preferredTimescale: 24));
        }
        
        self.videoPlayerLayer.controlTimebase = controlTimebase
        

       
        
        videoDecoder.delegate = self
        
      
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
        
            guard let filePath =  Bundle.main.path(forResource: "ma", ofType: "mp4") else { return }
            //let fileURL = URL(fileURLWithPath: filePath)
            let url = URL(fileURLWithPath: filePath)
            let reader = FileReader(url: url)
            let mediaReader = MediaFileReader(fileReader: reader!, type: .mp4)
            mediaReader.decodeMedia(type: .mp4)
            let tracks = mediaReader.makeTracks()
            
            videoDecoder.track = tracks[0]
//        tracks[0].samples.forEach {
//            print($0.startTime , $0.duration)
//        }
        
            var frames: [[UInt8]] = []
                    for sample in tracks[0].samples {
                        mediaReader.fileReader.seek(offset: UInt64(sample.offset))
                        mediaReader.fileReader.read(length: sample.size) { (data) in
            
                            frames.append(Array(data))
        
                        }
                    }
                    //videoDecoder.track = tracks[0]
        let timingPts = tracks[0].samples.map {
            $0.compositionTimeOffset
        }
        
       
       videoDecoder.decodeTrack(samples: frames, pts: timingPts)
  
  /*      videoPlayerLayer.requestMediaDataWhenReady(on: serialQueue, using: { [weak self] in
            guard let self = self else { return }
            while self.videoPlayerLayer.isReadyForMoreMediaData {
                if let sample = self.copyNextSample() {
       
                
                    self.videoPlayerLayer.enqueue(sample)
               
                } else {
                    self.videoPlayerLayer.stopRequestingMediaData()
                }
                
                
            }
        })
    */
    }
    
    @objc func readButtonDidTap() {
      
       
        audioDecoder?.play()
//        var frames: [[UInt8]] = []
//        for sample in tracks[1].samples {
//            //print(sample.offset)
//            mediaReader.fileReader.seek(offset: UInt64(sample.offset))
//           // print(sample.size)
//            mediaReader.fileReader.read(length: sample.size) { (data) in
//
//               /* data.forEach {
//                    print($0)
//                }*/
//               // print(data)
//                frames.append(Array(data))
//                //print(Array(data))
//
//              //  print("_________data")
//            }
//        }
//        //videoDecoder.track = tracks[0]
//
//       // videoDecoder.decodeTrack(frames: frames)
//
//       // audioDecoder.decodeTrack(frames: frames)
        
 
    }
}

extension PlayerViewContoller: MultiMediaDecoderDelegate {
    func shouldUpdateLayer(with buffer: CMSampleBuffer) {
     //  AVAudioSession().
        //localBuffer.append(buffer)
        //semaphore.wait()
        semaphore.wait()
        if self.videoPlayerLayer.isReadyForMoreMediaData {
            self.videoPlayerLayer.enqueue(buffer)
            self.videoPlayerLayer.setNeedsDisplay()
            print(CMSampleBufferGetOutputPresentationTimeStamp(buffer))
            print(CMSampleBufferGetOutputDuration(buffer))
        }
        semaphore.signal()
    }
    
    
    func copyNextSample() -> CMSampleBuffer? {
        if localBuffer.isEmpty {
            return nil
        }
        let sample = localBuffer.first!
       // semaphore.wait()
        localBuffer.remove(at: 0)
        
        return sample
    }
    
}
