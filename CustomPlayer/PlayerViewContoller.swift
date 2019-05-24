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
    let lockQueue = DispatchQueue(label: "lock queue")
    var localBuffer: [CMSampleBuffer] = []
    var count = 0
    let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    var tracks: [Track] = []
    let audioRenderer = AVSampleBufferAudioRenderer()
    let renderSynchronizer = AVSampleBufferRenderSynchronizer()
    
    var audioTrackDecoder: TrackDecodable?
    var videoTrackDecoder: TrackDecodable?
   
    private lazy var playerView: CustomizedPlayerView = {
        let view = CustomizedPlayerView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.initializeVideoLayer()
        view.duration = Float(moviePlayer!.totalDuration / 1000)
        return view
    }()
    
    
    private lazy var moviePlayer: MoviePlayer? = {
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8") else {
            return nil
        }
        //https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8
        //https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8
        //https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8
        //https://video-dev.github.io/streams/test_001/stream.m3u8
        //https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8
//        guard let filePath = Bundle.main.path(forResource: "you", ofType: "mp4") else { return nil }
//        let url = URL(fileURLWithPath: filePath)
        let player: MoviePlayer = MoviePlayer(url: url)
        player.delegate = self
        return player
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
        // renderSynchronizer.addRenderer(audioRenderer)
       // setUpLayer()
        setUpViews()
        setPlayHandlers()
        print(moviePlayer?.totalDuration)
        print(Float(moviePlayer!.totalDuration / 1000))
        playerView.duration = Float(moviePlayer!.totalDuration / 1000)
        //VideoTrackDecoder.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveSeekValue(_:)), name: NSNotification.Name(rawValue: "trackValueChangedToSeek"), object: nil)
       
      
        // Do any additional setup after loading the view.
    }

 
    @objc func didReceiveSeekValue(_ notification: Notification)
    {
    
        guard let seekValue = notification.userInfo?["value"] as? Float else {return}
        let value = Double(seekValue)
        moviePlayer?.seek(to: value)
        
    }
   
    private func setUpViews() {
        view.backgroundColor = .black
        view.addSubview(playerView)
        playerView.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        playerView.leadingAnchor.constraint(
            equalTo: view.leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(
            equalTo: view.trailingAnchor).isActive = true
        playerView.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: 0.33).isActive = true
        
       
        
    }
    
    
    private func setPlayHandlers() {
        playerView.playHandler = { [weak self] in
            guard let self = self else { return nil}
            self.playerView.playButton.isSelected = !self.playerView.playButton.isSelected
            
            if self.playerView.playButton.isSelected {
                self.playerView.playButton.setImage(#imageLiteral(resourceName: "pauseButtonImage"), for: .normal)
                self.moviePlayer?.play()
                //https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8
               /* guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8") else {
                    return nil
                }*/
                self.moviePlayer?.loadPlayerAsynchronously(completion: { [weak self] (result) in
                    
                    switch result {
                    case .failure(let error):
                        print(error.localizedDescription)
                    case .success(let data):
                        print(data)
                    }
                })

                
                
            } else {
                self.playerView.playButton.setImage(#imageLiteral(resourceName: "playButtonImage"), for: .normal)
                self.moviePlayer?.pause()
            }
            
            return nil
        }
        
        playerView.sliderInterupter = { [weak self] in
            guard let self = self else { return nil}
            self.playerView.playButton.isSelected = !self.playerView.playButton.isSelected
            self.moviePlayer?.pause()
            
            return nil
        }
    }
    

}


extension PlayerViewContoller: VideoQueueDelegate {
    func displayQueue(with buffers: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.playerView.displayFrame(buffers)
           // self.playerView.setNeedsDisplay()
     }
    }
}

extension PlayerViewContoller: MultiMediaVideoTypeDecoderDelegate {
    func prepareToDisplay(with buffers: CMSampleBuffer) {
        DispatchQueue.main.async {
           self.playerView.displayFrame(buffers)
          //   self.playerView.setNeedsDisplay()
        }
    }
    
    
}

struct DataPackage {
    let presentationTimestamp: [Int]
    var dataStorage: [Data]
}


