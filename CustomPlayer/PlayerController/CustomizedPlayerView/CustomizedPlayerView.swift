//
//  CustomizedPlayer.swift
//  CustomPlayer
//
//  Created by USER on 02/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import UIKit
import AVFoundation

class CustomizedPlayerView: UIView {
    
    private let videoPlayerLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
        layer.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0)
        return layer
    }()
    
    private var controlTimebase: CMTimebase? = nil
    
    private var clock: CMClock? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
        initializeVideoLayer()
        setTimebase()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setUpLayout() {
       
        self.layer.addSublayer(videoPlayerLayer)

    }
    
    
    @objc func didDragToSeek() {
//        sliderInterupter?()
//    
//        NotificationCenter.default.post(name: Notification.Name("trackValueChangedToSeek"), object: nil, userInfo: ["value": playTrackSlider.value])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
         videoPlayerLayer.frame = self.bounds
    }
    
    
    func initializeVideoLayer() {
        
        clock = CMClockGetHostTimeClock()
        
        assertDependOnMultiMediaValueStatus(
            CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault,
                                            masterClock: clock!,
                                            timebaseOut: &controlTimebase)
        )
    }
    
    func setRate(_ value: Float64 = 1.0) {
        CMTimebaseSetRate(controlTimebase!, rate: value);
    }
    
    func setTimebase(to time: CMTime = CMTime(value: 1, timescale: 24)) {
        guard let controlTimebase = self.controlTimebase else { return }
        CMTimebaseSetTime(controlTimebase, time: time)
    }
    
    func displayFrame(_ sample: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.videoPlayerLayer.enqueue(sample)
        }
    }

    
}
