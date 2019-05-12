//
//  DisplayLinkedQueue.swift
//  CustomPlayer
//
//  Created by bumslap on 11/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AVFoundation

protocol DisplayLinkedQueueDelegate: class {
    func queue(_ buffer: CMSampleBuffer)
}

final class DisplayLinkedQueue: NSObject {
    var running: Bool = false
    var bufferTime: TimeInterval = 1 // sec
    weak var delegate: DisplayLinkedQueueDelegate?
    private(set) var duration: TimeInterval = 0
    
    private var isReady: Bool = false
    private var buffers: [CMSampleBuffer] = []
    private var mediaTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink: CADisplayLink = displayLink else { return }
            displayLink.preferredFramesPerSecond = 30
            displayLink.add(to: .main, forMode: RunLoop.Mode.common)
        }
    }
    private let lockQueue = DispatchQueue(label: "com.bumslap.DisplayLinkedQueue.lock")
    
    func enqueue(_ buffer: CMSampleBuffer) {
        lockQueue.async {
            self.duration += buffer.duration.seconds
            self.buffers.append(buffer)
            if !self.isReady {
                self.isReady = self.duration <= self.bufferTime
            }
        }
    }
    
    @objc func update(displayLink: CADisplayLink) {
        guard let first: CMSampleBuffer = buffers.first, isReady else { return }
        if mediaTime == 0 {
            mediaTime = displayLink.timestamp
        }
        if first.presentationTimeStamp.seconds <= displayLink.timestamp {
            lockQueue.async {
                self.buffers.removeFirst()
            }
            delegate?.queue(first)
        }
    }
    
    func startRunning() {
        lockQueue.async {
            guard !self.running else { return }
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.update(displayLink:)))
            self.running = true
        }
    }
    
    func stopRunning() {
        lockQueue.async {
            guard self.running else { return }
            self.displayLink = nil
            self.buffers.removeAll()
            self.running = false
        }
    }
}

