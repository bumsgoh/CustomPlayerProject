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
    var enCount = 0
    var deCount = 0
    private let lockQueue = DispatchQueue(label: "com.bumslap.DisplayLinkedQueue.lock")
    private let bufferSize = 128
    
    var running: Bool = false
    var bufferTime: TimeInterval = 0.5 // sec
    
    @objc dynamic var isBufferFull: Bool = false
    private var bufferCount = 0
    weak var delegate: DisplayLinkedQueueDelegate?
    
    private(set) var duration: TimeInterval = 0
    private var buffers: [CMSampleBuffer] = []
    @objc dynamic var isReady: Bool = false
    private var mediaTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink: CADisplayLink = displayLink else { return }
            displayLink.preferredFramesPerSecond = 30
            displayLink.add(to: .main, forMode: .common)
        }
    }
   
    
    func enqueue(_ buffer: CMSampleBuffer) {
        lockQueue.async {
           // print("enqued: \(self.enCount)")
            self.enCount += 1
            self.duration += buffer.duration.seconds
            self.buffers.append(buffer)
            self.bufferCount += 1
            
            if self.bufferCount >= self.bufferSize {
                self.isBufferFull = true
            }
            
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
             //   print("dequed: \(self.deCount)")
                self.deCount += 1
                self.buffers.removeFirst()
                self.bufferCount -= 1
                if self.buffers.count <= self.bufferSize / 2 {
                    
                    
                    self.isBufferFull = false
                    
                }
               
            }
             self.delegate?.queue(first)
            
            
        }
    }
    
    func fetchPtsOfLastItemInBuffer() -> CMTime? {
        guard let pts =  buffers.last?.presentationTimeStamp else { return nil }
        return pts
    }
    
    func start() {
        lockQueue.async {
            guard !self.running else { return }
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.update(displayLink:)))
            self.running = true
        }
    }
    
    func pause() {
        lockQueue.async {
            guard self.running else { return }
            self.displayLink = nil
           // self.buffers.removeAll()
            self.running = false
        }
    }
}

