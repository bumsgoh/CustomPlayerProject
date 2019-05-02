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
    
    private var videoDecoder: VideoFrameDecodable
    private var audioDecoder: AudioFrameDecoder
    let audioRenderer = AVSampleBufferAudioRenderer()
    private var videoPlayerLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
        let timebasePointer =
            UnsafeMutablePointer<CMTimebase?>.allocate(capacity: 1)
        let status =
            CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault,
                                            masterClock: CMClockGetHostTimeClock(),
                                            timebaseOut: timebasePointer)
        layer.controlTimebase = timebasePointer.pointee
        guard let controlTimebase = layer.controlTimebase,
            status == noErr else {
            print("no timebase control")
            return layer
        }
        CMTimebaseSetTime(controlTimebase, time: CMTime.zero)
        CMTimebaseSetRate(controlTimebase, rate: 1.0)
        
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
    
    init(videoDecoder: VideoFrameDecodable) {
        self.videoDecoder = videoDecoder
        self.audioDecoder = AudioFrameDecoder()
        
        super.init(nibName: nil, bundle: nil)
        self.audioDecoder.videoDecoderDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videoDecoder.layer = self.videoPlayerLayer
        setUpLayer()
        setUpViews()
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
        DispatchQueue.global().async {
            guard let filePath =  Bundle.main.path(forResource: "animation", ofType: "h264") else { return }
            let fileURL = URL(fileURLWithPath: filePath)
            self.videoDecoder.decodeFile(url: fileURL)
        }
    }
    
    @objc func readButtonDidTap() {
        guard let filePath =  Bundle.main.path(forResource: "walk", ofType: "mp4") else { return }
        let url = URL(fileURLWithPath: filePath)
        let reader = FileReader(url: url)
        let mediaReader = MediaFileReader(fileReader: reader!, type: .mp4)
        mediaReader.decodeFile(type: .mp4)
        let tracks = mediaReader.makeTracks()
        
        var frames: [[UInt8]] = []
        for sample in tracks[1].samples {
            //print(sample.offset)
            mediaReader.fileReader.seek(offset: UInt64(sample.offset))
           // print(sample.size)
            mediaReader.fileReader.read(length: sample.size) { (data) in
                
               /* data.forEach {
                    print($0)
                }*/
               // print(data)
                frames.append(Array(data))
                //print(Array(data))
                
              //  print("_________data")
            }
        }
        //videoDecoder.track = tracks[0]
        
       // videoDecoder.decodeTrack(frames: frames)
        
       // audioDecoder.decodeTrack(frames: frames)
        

    }
}

extension PlayerViewContoller: VideoDecoderDelegate {
    func shouldUpdateVideoLayer(with buffer: CMSampleBuffer) {
      self.audioRenderer.enqueue(buffer)
        DispatchQueue.main.async {
           // self.videoPlayerLayer.enqueue(buffer)
           
           // self.videoPlayerLayer.setNeedsDisplay()
        }
        }
    
}
