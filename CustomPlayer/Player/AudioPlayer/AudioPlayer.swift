//
//  AudioPlayer.swift
//  CustomPlayer
//
//  Created by bumslap on 06/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AudioToolbox



enum AudioPlayerState {
    case playing
    case paused
    case stopped
}


class AudioPlayer: NSObject {
    
    var count = 0
    var frames: [Data] = []
    var dataTask: URLSessionDataTask?
    var fileStreamID: AudioFileStreamID? = nil
    var streamDescription: AudioStreamBasicDescription?
    var audioQueue: AudioQueueRef?
    var fileURL: URL
    var isRunning: UInt32 = 0
    var state: AudioPlayerState = .stopped
    var passedData: Data
    
    var streamPropertyListenerProc: AudioFileStream_PropertyListenerProc = { (clientData, audioFileStreamID, propertyID, ioFlags) -> Void in
        
        let selfPointee: AudioPlayer = unsafeBitCast(clientData, to: AudioPlayer.self)
        //let selfPointee = Unmanaged<AudioPlayer>.fromOpaque(clientData).takeUnretainedValue()
        if propertyID == kAudioFileStreamProperty_DataFormat {
            var status: OSStatus = 0
            var dataSize: UInt32 = 0
            var writable: DarwinBoolean = false
            status = AudioFileStreamGetPropertyInfo(audioFileStreamID, kAudioFileStreamProperty_DataFormat, &dataSize, &writable)
            assert(noErr == status)
            var audioStreamDescription = AudioStreamBasicDescription()
            status = AudioFileStreamGetProperty(audioFileStreamID, kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription)
            assert(noErr == status)
            /* let asbd = AudioStreamBasicDescription(
             mSampleRate: 44100,
             mFormatID: kAudioFormatMPEG4AAC,
             mFormatFlags: 0,
             mBytesPerPacket: 0,
             mFramesPerPacket: 1024,
             mBytesPerFrame: 0,
             mChannelsPerFrame: 2,
             mBitsPerChannel: 0,
             mReserved: 0)*/
            DispatchQueue.main.async {
                selfPointee.createAudioQueue(audioStreamDescription)
            }
        }
    }
    
    let streamPacketsProc: AudioFileStream_PacketsProc = { (clientData, numberBytes, numberPackets, inputData, packetDescriptions) -> Void in
        
        let selfPointee: AudioPlayer = unsafeBitCast(clientData, to: AudioPlayer.self)
        //      print("numberBytes = \(numberBytes),numberPackets = \(numberPackets)")
        var buffer: AudioQueueBufferRef? = nil
        if let audioQueue = selfPointee.audioQueue {
            AudioQueueAllocateBuffer(audioQueue, numberBytes, &buffer)
            buffer?.pointee.mAudioDataByteSize = numberBytes
            // print(packetDescriptions)
            memcpy(buffer?.pointee.mAudioData, inputData, Int(numberBytes)) //copied to buffer
            AudioQueueEnqueueBuffer(audioQueue, buffer!, numberPackets, packetDescriptions)
            AudioQueuePrime(audioQueue, 5, nil)
            AudioQueueStart (audioQueue, nil)
            //selfPointee.isRunning = 1
        }
    }
    
    fileprivate var AudioQueuePropertyCallbackProc: AudioQueuePropertyListenerProc = { (clientData, audioQueueRef, propertyID) in
        let selfPointee = unsafeBitCast(clientData, to: AudioPlayer.self)
        if propertyID == kAudioQueueProperty_IsRunning {
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            AudioQueueGetProperty(audioQueueRef, propertyID, &isRunning, &size)
            selfPointee.isRunning = isRunning
        }
    }
    
    fileprivate var outputCallback: AudioQueueOutputCallback = { (clientData: UnsafeMutableRawPointer?, audioQueue: AudioQueueRef, buffer: AudioQueueBufferRef) -> Void in
        let selfPointee = Unmanaged<AudioPlayer>.fromOpaque(clientData!).takeUnretainedValue()
        AudioQueueFreeBuffer(audioQueue, buffer)
    }
    
    var volume: Float = 3.0 {
        didSet {
            if let audioQueue = audioQueue {
                AudioQueueSetParameter(audioQueue, AudioQueueParameterID(kAudioQueueParam_Volume), Float32(volume))
            }
        }
    }
    
    init(url: URL, data: Data) {
        fileURL = url
        self.passedData = data
        super.init()
        let selfPointee = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        AudioFileStreamOpen(selfPointee, streamPropertyListenerProc, streamPacketsProc, kAudioFormatMPEG4AAC, &self.fileStreamID)
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = urlSession.dataTask(with: fileURL)
        
    }
    
    deinit {
        if let audioQueue = audioQueue {
            AudioQueueReset(audioQueue)
        }
        AudioFileStreamClose(fileStreamID!)
    }
    
    func play() {
        
            self.callback()
        
       // dataTask?.resume()
        if let audioQueue = audioQueue {
            AudioQueueStart(audioQueue,nil)
        }
    }
    func pause() {
        if let audioQueue = audioQueue {
            let status = AudioQueuePause(audioQueue)
            if status != noErr {
                print("=====  Pause failed: \(status)")
            }
        }
    }
    
    fileprivate func createAudioQueue(_ audioStreamDescription: AudioStreamBasicDescription) {
        var audioStreamDescription = audioStreamDescription
        print(audioStreamDescription)
        self.streamDescription = audioStreamDescription
        var status: OSStatus = 0
        let selfPointee = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        status = AudioQueueNewOutput(&audioStreamDescription, outputCallback, selfPointee, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.audioQueue)
        assert(status == noErr)
        status = AudioQueueAddPropertyListener(self.audioQueue!, kAudioQueueProperty_IsRunning, AudioQueuePropertyCallbackProc, selfPointee)
        assert(status == noErr)
        //   AudioQueuePrime(self.audioQueue!, 6, nil)
        AudioQueueStart(audioQueue!, nil)
        
    }
    
    func callback() {
        var parseFlags: AudioFileStreamParseFlags
        var count = 0
        var offset = 0
        let indicies = passedData.count / 128
        while true {
            let data = passedData.subdata(in: (passedData.startIndex + offset)..<(passedData.startIndex + offset + 128))
            if count > indicies { break }
            offset += 128
            count += 1
            if state == .paused { //paused
                parseFlags = .discontinuity
            } else {
                parseFlags = AudioFileStreamParseFlags(rawValue: 0)
                let status = AudioFileStreamParseBytes(self.fileStreamID!, UInt32(data.count), (data as NSData).bytes, parseFlags)
                if status == noErr {
                  //  print("parse succeed")
                }
            }
        }
        
            
        }
}

extension AudioPlayer: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        var parseFlags: AudioFileStreamParseFlags
        if state == .paused { //paused
            parseFlags = .discontinuity
        } else {
            parseFlags = AudioFileStreamParseFlags(rawValue: 0)
            let status = AudioFileStreamParseBytes(self.fileStreamID!, UInt32(passedData.count), (passedData as NSData).bytes, parseFlags)
            print(status)
            
        }
        
        
    }
}
