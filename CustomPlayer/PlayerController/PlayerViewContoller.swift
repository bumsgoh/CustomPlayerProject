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
    var tracks: [Track] = []
    var isPlayable: Bool = false
    var state: MediaStatus = .stopped
    var moviePlayableContext: Int = 1
    var audioTrackDecoder: TrackDecodable?
    var videoTrackDecoder: TrackDecodable?
    var timebase: Double = 0
    var isFirstFrame = true
    var currentVolume: Float = 1
   var currentDuration: TimeInterval = 0
    
    private let volumeControllerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.backgroundColor = #colorLiteral(red: 0.1411602199, green: 0.1411868036, blue: 0.1411544085, alpha: 1)
        return view
    }()
    
    private let spekerImage: UIImageView = {
        let view = UIImageView(image: #imageLiteral(resourceName: "speakerImg"))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var volumeSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.setThumbImage(#imageLiteral(resourceName: "thumbImage"), for: .normal)
        slider.minimumTrackTintColor = #colorLiteral(red: 0.4901509881, green: 0.4902249575, blue: 0.4901347756, alpha: 1)
        slider.maximumTrackTintColor = #colorLiteral(red: 0.2274276018, green: 0.2274659276, blue: 0.2274191976, alpha: 1)
        slider.addTarget(self, action: #selector(didVolumeBarMove), for: .valueChanged)
        slider.maximumValue = 5
        slider.value = 1
        slider.isContinuous = false
        return slider
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private lazy var playerView: CustomizedPlayerView = {
        let view = CustomizedPlayerView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.initializeVideoLayer()
        return view
    }()
    
    private let playerControllerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.backgroundColor = #colorLiteral(red: 0.1411602199, green: 0.1411868036, blue: 0.1411544085, alpha: 1)
        return view
    }()
    
    private lazy var playTrackSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.transform = CGAffineTransform(scaleX: 1, y: 1)
        slider.setThumbImage(#imageLiteral(resourceName: "thumbImage"), for: .normal)
        slider.minimumTrackTintColor = #colorLiteral(red: 0.4901509881, green: 0.4902249575, blue: 0.4901347756, alpha: 1)
        slider.maximumTrackTintColor = #colorLiteral(red: 0.2274276018, green: 0.2274659276, blue: 0.2274191976, alpha: 1)
        return slider
    }()
    
    private let playerControllerStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillProportionally
        stackView.backgroundColor = .white
        return stackView
    }()
    
    private let playerTimerStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.backgroundColor = .white
        return stackView
    }()
    
    private let playerTimerClockLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        label.text = "00: 00"
        return label
    }()
    
    private let playerTimerDurationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        label.text = "00: 00"
        return label
    }()
    
    private let playerButtonsStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.backgroundColor = .white
        return stackView
    }()
    
    private let playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        button.setImage(#imageLiteral(resourceName: "playBtn"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    
    private let multiTrackButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(#imageLiteral(resourceName: "multiButton"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    
    private let indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.style = .white
        return indicator
    }()
    
    private var playerViewHeightAnchor: NSLayoutConstraint?
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(viewDidTap))
        return recognizer
    }()
    
    private lazy var moviePlayer: MoviePlayer? = {
        guard let url: URL = URL(string: "https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8") else {
            return nil
        }
        
        //https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8
        //https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8
        //https://video-dev.github.io/streams/test_001/stream.m3u8
        //https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8
//        guard let filePath = Bundle.main.path(forResource: "you", ofType: "mp4") else { return nil }
//       let url = URL(fileURLWithPath: filePath)
        let player: MoviePlayer = MoviePlayer(url: url)
        player.delegate = self
        return player
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
       // print(playTrackSlider.maximumValue)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveSeekValue(_:)), name: NSNotification.Name(rawValue: "trackValueChangedToSeek"), object: nil)
        setObservers()
        UIVisualEffectView.appearance(whenContainedInInstancesOf: [UIAlertController.classForCoder() as! UIAppearanceContainer.Type]).effect = UIBlurEffect(style: .dark)
        // Do any additional setup after loading the view.
    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.orientation.isLandscape {
            playerViewHeightAnchor?.constant = size.height
        } else {
            playerViewHeightAnchor?.constant = view.frame.height * 0.2
        }
    }

    private func setObservers() {
        moviePlayer?.addObserver(self,
                                 forKeyPath: "isPlayable",
                                 options: [.new, .old ],
                                 context: &moviePlayableContext)
    }
   


    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard context == &moviePlayableContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(MoviePlayer.isPlayable) {
            guard let oldValue = change?[.oldKey] as? Bool,
                let newValue = change?[.newKey] as? Bool else { return }
            if oldValue != newValue {
                if newValue {
                    DispatchQueue.main.async {
                         self.indicator.stopAnimating()
                    }
                   
                    
                    
                } else {
                    DispatchQueue.main.async {
                        self.indicator.startAnimating()
                    }
                }
            }
        }
    }
 
    @objc func didReceiveSeekValue(_ notification: Notification) {
    
        guard let seekValue = notification.userInfo?["value"] as? Float else {return}
        let value = Double(seekValue)
        moviePlayer?.seek(to: value)
        
    }
    
    @objc func didVolumeBarMove(sender: UISlider) {
        moviePlayer?.volume = sender.value
    }
   
    private func setUpViews() {
        view.addGestureRecognizer(tapGestureRecognizer)
        view.backgroundColor = .black
        view.addSubview(volumeControllerContainerView)
        view.addSubview(playerView)
        view.addSubview(multiTrackButton)
        
        volumeControllerContainerView.addSubview(volumeSlider)
        volumeControllerContainerView.addSubview(spekerImage)
        
        volumeControllerContainerView.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        volumeControllerContainerView.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16).isActive = true
        volumeControllerContainerView.widthAnchor.constraint(
            equalTo: view.widthAnchor, multiplier: 0.4).isActive = true
        volumeControllerContainerView.heightAnchor.constraint(
            equalToConstant: 50).isActive = true
        
        spekerImage.trailingAnchor.constraint(
            equalTo: volumeControllerContainerView.trailingAnchor, constant: -16).isActive = true
        spekerImage.centerYAnchor.constraint(
            equalTo: volumeControllerContainerView.centerYAnchor).isActive = true
        
        volumeSlider.trailingAnchor.constraint(
            equalTo: spekerImage.leadingAnchor, constant: -8).isActive = true
        volumeSlider.centerYAnchor.constraint(
            equalTo: volumeControllerContainerView.centerYAnchor).isActive = true
        volumeSlider.widthAnchor.constraint(
            equalTo: volumeControllerContainerView.widthAnchor,
            multiplier: 0.6).isActive = true
       
        
        playerView.centerYAnchor.constraint(
            equalTo: view.centerYAnchor).isActive = true
        playerView.leadingAnchor.constraint(
            equalTo: view.leadingAnchor).isActive = true
        playerView.trailingAnchor.constraint(
            equalTo: view.trailingAnchor).isActive = true
        
        if UIDevice.current.orientation.isLandscape {
           playerViewHeightAnchor = NSLayoutConstraint(item: playerView, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 1)
        } else {
            playerViewHeightAnchor = NSLayoutConstraint(item: playerView, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 0.33, constant: 1)
        }
        playerViewHeightAnchor?.isActive = true
        
        view.addSubview(indicator)
        indicator.centerYAnchor.constraint(
            equalTo: playerView.centerYAnchor).isActive = true
        indicator.centerXAnchor.constraint(
            equalTo: playerView.centerXAnchor).isActive = true
        
        
        setUpPlayerController()
    }
    
    func setUpPlayerController() {
        view.addSubview(playerControllerContainerView)
        playerControllerContainerView.addSubview(playerControllerStackView)
        
        
        playerControllerStackView.addArrangedSubview(playTrackSlider)
        playerControllerStackView.addArrangedSubview(playerTimerStackView)
        playerControllerStackView.addArrangedSubview(playerButtonsStackView)
        
        
        playerControllerContainerView.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor,
            constant: 24).isActive = true
        playerControllerContainerView.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -24).isActive = true
        playerControllerContainerView.heightAnchor.constraint(
            equalToConstant: 120).isActive = true
        playerControllerContainerView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -8).isActive = true
        
        multiTrackButton.addTarget(self, action: #selector(multiTrackButtonDidTap), for: .touchUpInside)
        multiTrackButton.isHidden = true
        multiTrackButton.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -24).isActive = true
        multiTrackButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -8).isActive = true
        
        
        
        playerControllerStackView.leadingAnchor.constraint(
            equalTo: playerControllerContainerView.leadingAnchor, constant: 16).isActive = true
        playerControllerStackView.trailingAnchor.constraint(
            equalTo: playerControllerContainerView.trailingAnchor, constant: -16).isActive = true
        playerControllerStackView.centerYAnchor.constraint(
            equalTo: playerControllerContainerView.centerYAnchor).isActive = true
        playerControllerStackView.heightAnchor.constraint(
            equalTo: playerControllerContainerView.heightAnchor,
            multiplier: 0.8).isActive = true

        playerTimerStackView.addArrangedSubview(playerTimerClockLabel)
        playerTimerStackView.addArrangedSubview(playerTimerDurationLabel)
        playerButtonsStackView.addArrangedSubview(playButton)
        
        playButton.addTarget(self, action: #selector(playButtonDidTouch), for: .touchUpInside)
       // playerButtonsStackView.heightAnchor.constraint(equalToConstant: 60).isActive = true

    }
    
    
    @objc private func playButtonDidTouch() {
        playButton.isSelected = !playButton.isSelected
        playButton.isEnabled = false
        if playButton.isSelected {
            playButton.setImage(#imageLiteral(resourceName: "pauseBtn"), for: .normal)
            if state == .paused {
                playButton.isEnabled = true
                moviePlayer?.resume()
                return
            }
            indicator.startAnimating()
            moviePlayer?.loadPlayerAsynchronously(completion: { [weak self] (result) in
                guard let self = self else { return }
                switch result {
                case .failure:
                    return
                case .success:
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        guard let duration = self.moviePlayer?.totalDuration else { return }
                        self.state = .playing
                        let durationSeconds = duration / 1000
                        
                        self.playButton.isEnabled = true
                        
                        self.playTrackSlider.maximumValue = Float(durationSeconds)
                        let totalDuration: TimeInterval = TimeInterval(durationSeconds)
                        
                        let s: Int = Int(totalDuration) % 60
                        let m: Int = Int(totalDuration) / 60
                        
                        let formattedDuration = String(format: "%0d:%02d", m, s)
                        self.playerTimerDurationLabel.text = formattedDuration
                        self.moviePlayer?.resume()
                        self.indicator.stopAnimating()
                    }
                   
                }
            })
           
        } else {
            
            playButton.setImage(#imageLiteral(resourceName: "playBtn"), for: .normal)
            self.moviePlayer?.pause()
            self.playButton.isEnabled = true
            state = .paused
        }
    }
    
    @objc func viewDidTap() {
        
        UIView.transition(with: view,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: {
            self.playerControllerContainerView.isHidden = !self.playerControllerContainerView.isHidden
            
            self.volumeControllerContainerView.isHidden = !self.volumeControllerContainerView.isHidden
            
            self.multiTrackButton.isHidden = !self.multiTrackButton.isHidden
        })
    }
    
    @objc func multiTrackButtonDidTap() {
        let alertController = UIAlertController(title: "Multi Track", message: "select video's point of view", preferredStyle: .alert)
       
       
        let firstTrack = UIAlertAction(title: "track #1", style: .default) { (action) in
            
            guard let firstTrackURL: URL = URL(string: "https://video-dev.github.io/streams/test_001/stream.m3u8") else {
                return
            }
          
            self.moviePlayer?.interruptCall(with: .multiTrackRequest(firstTrackURL))
                
            }
        
        firstTrack.setValue(UIColor.white, forKey: "titleTextColor")
        
        let secondTrack = UIAlertAction(title: "track #2", style: .default) { (action) in
            guard let secondTrackURL: URL = URL(string: "https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8") else {
                return
            }
            
            self.moviePlayer?.interruptCall(with: .multiTrackRequest(secondTrackURL))
            
        }
        
        secondTrack.setValue(UIColor.white, forKey: "titleTextColor")
        
        let thirdTrack = UIAlertAction(title: "track #3", style: .default) { (action) in
            guard let thirdTrackURL: URL = URL(string: "https://video-dev.github.io/streams/x36xhzz/x36xhzz.m3u8") else {
                return
            }
            
            self.moviePlayer?.interruptCall(with: .multiTrackRequest(thirdTrackURL))
            
    }
        
        thirdTrack.setValue(UIColor.white, forKey: "titleTextColor")
       
        let cancelAction = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
        
        alertController.addAction(firstTrack)
        alertController.addAction(secondTrack)
        alertController.addAction(thirdTrack)
       
        alertController.addAction(cancelAction)
         alertController.view.addSubview(UIView())
        present(alertController, animated: true)
    }
    
}


extension PlayerViewContoller: VideoQueueDelegate {
    func displayQueue(with buffers: CMSampleBuffer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playerView.displayFrame(buffers)
            
            if self.isFirstFrame {
                self.timebase = buffers.presentationTimeStamp.seconds
                self.isFirstFrame = false
            }
            self.currentDuration += 0.03
//
//            if self.timebase > 0 {
//
//                currentDuration = TimeInterval(buffers.presentationTimeStamp.seconds - self.timebase) / 1000
//                self.playTrackSlider.setValue(Float(currentDuration), animated: true)
//            } else {
//                currentDuration = TimeInterval(buffers.presentationTimeStamp.seconds)
//
//            }
//
             self.playTrackSlider.setValue(Float(self.currentDuration), animated: true)
            let s: Int = Int(self.currentDuration) % 60
            let m: Int = Int(self.currentDuration) / 60
            
            let formattedDuration = String(format: "%02d:%02d", m, s)
            self.playerTimerClockLabel.text = formattedDuration
     }
    }
}


struct DataPackage {
    let presentationTimestamp: [Int]
    var dataStorage: [Data]
}

