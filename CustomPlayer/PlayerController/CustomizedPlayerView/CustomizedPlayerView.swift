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
        layer.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        return layer
    }()
    
    let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(#imageLiteral(resourceName: "playButtonImage"), for: .normal)
        button.tintColor = .white
        button.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        return button
    }()
    
    var playHandler: (() -> Void?)? = nil
    
    var sliderInterupter: (() -> Void?)? = nil
    
    private lazy var playTrackSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        slider.setThumbImage(#imageLiteral(resourceName: "thumb"), for: .normal)
       
        return slider
    }()
    
    var duration: Float = 0
    
    private let playBarStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.backgroundColor = .white
        //stackView.distribution =
        return stackView
    }()
    
    private var controlTimebase: CMTimebase? = nil
    private var clock: CMClock? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
        playButton.addTarget(self, action: #selector(executePlayButtonHandler), for: .touchUpInside)
        initializeVideoLayer()
        playTrackSlider.maximumValue = 101
        print("is..\(duration)")
        playTrackSlider.minimumValue = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setUpLayout() {
       
        self.layer.addSublayer(videoPlayerLayer)
        
        self.addSubview(playBarStackView)
        
        playBarStackView.addArrangedSubview(playButton)
        playBarStackView.addArrangedSubview(playTrackSlider)
        
        playBarStackView.leadingAnchor.constraint(
            equalTo: self.leadingAnchor,constant: 8).isActive = true
        playBarStackView.trailingAnchor.constraint(
            equalTo: self.trailingAnchor, constant: 8).isActive = true
        playBarStackView.bottomAnchor.constraint(
            equalTo: self.bottomAnchor).isActive = true
       /* playBarStackView.heightAnchor.constraint(
            equalToConstant: 16).isActive = true*/
        playTrackSlider.addTarget(self, action: #selector(didDragToSeek), for: .valueChanged)
        playTrackSlider.isContinuous = false
    }
    
    func setNotifications() {
        
    }
    
    @objc func didDragToSeek() {
        sliderInterupter?()
    
        NotificationCenter.default.post(name: Notification.Name("trackValueChangedToSeek"), object: nil, userInfo: ["value": playTrackSlider.value])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
         videoPlayerLayer.frame = self.frame
    }
    
    
    @objc func executePlayButtonHandler() {
        guard let handler = playHandler else { return }
        handler()
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
     //   self.videoPlayerLayer.enqueue(sample)
       // print(playTrackSlider.maximumValue)
       // playTrackSlider.setValue(Float(sample.presentationTimeStamp.seconds), animated: true)
    }

    
}
