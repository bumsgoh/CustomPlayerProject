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
        guard let filePath = Bundle.main.path(forResource: "you", ofType: "mp4") else { return nil }
        let url = URL(fileURLWithPath: filePath)
        let player: MoviePlayer = MoviePlayer(url: url)
        player.delegate = self
        player.prepareToPlay()
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

        print(moviePlayer?.totalDuration)
        print(Float(moviePlayer!.totalDuration / 1000))
        playerView.duration = Float(moviePlayer!.totalDuration / 1000)
       
      
        //VideoTrackDecoder.delegate = self
        
      
        // Do any additional setup after loading the view.
    }

   
    private func setUpViews() {
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

    


}


extension PlayerViewContoller: VideoQueueDelegate {
    func displayQueue(with buffers: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.playerView.displayFrame(buffers)
        }
    }
}

struct DataPackage {
    let presentationTimestamp: [Int]
    var dataStorage: [Data]
}
