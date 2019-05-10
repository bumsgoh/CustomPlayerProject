//
//  AudioPlayer.swift
//  CustomPlayer
//
//  Created by bumslap on 06/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AudioToolbox


class AudioPlayer: NSObject {

    private var streamDescription: AudioStreamBasicDescription?
    private var isRunning: UInt32 = 0
    private var state: MediaStatus = .stopped
    private var passedData: Data
    
    
    private lazy var parse = {
        self.parseDeliveredData()
    }
    private var audioQueue:AudioQueueRef? = nil {
        didSet {
            guard let oldValue:AudioQueueRef = oldValue else {
                return
            }
            AudioQueueStop(oldValue, true)
            AudioQueueDispose(oldValue, true)
        }
    }
    private var fileStreamID:AudioFileStreamID? = nil {
        didSet {
            guard let oldValue:AudioFileStreamID = oldValue else {
                return
            }
            AudioFileStreamClose(oldValue)
        }
    }
    
   private var propertyListener: AudioFileStream_PropertyListenerProc = { (clientData,
        audioFileStreamID,
        propertyID,
        ioFlags) -> Void in
        
        let audioPlayerSelfPointer: AudioPlayer = unsafeBitCast(clientData,
                                                                to: AudioPlayer.self)
        guard propertyID == kAudioFileStreamProperty_DataFormat else { return }
        var sizeOfProperty: UInt32 = 0
        var isWritable: DarwinBoolean = false
        var audioStreamDescription = AudioStreamBasicDescription()
   
   
       assertDependOnMultiMediaValueStatus(
            AudioFileStreamGetPropertyInfo(audioFileStreamID,
            kAudioFileStreamProperty_DataFormat,
            &sizeOfProperty,
            &isWritable)
        )
    
        assertDependOnMultiMediaValueStatus(
            AudioFileStreamGetProperty(audioFileStreamID,
                                       kAudioFileStreamProperty_DataFormat,
                                       &sizeOfProperty,
                                       &audioStreamDescription)
            )
        audioPlayerSelfPointer.makeNewAudioQueue(audioStreamDescription)}
    
    
    
   private var packetInformationListner: AudioFileStream_PacketsProc = { (clientData,
        numberBytes,
        numberPackets,
        inputData,
        packetDescriptions) -> Void in
        let audioPlayerSelfPointer: AudioPlayer = unsafeBitCast(clientData,
                                                                to: AudioPlayer.self)

        var audioQueuebuffer: AudioQueueBufferRef?
        
        guard let audioQueue = audioPlayerSelfPointer.audioQueue else { return }
        AudioQueueAllocateBuffer(audioQueue, numberBytes, &audioQueuebuffer)
        audioQueuebuffer?.pointee.mAudioDataByteSize = numberBytes
        memcpy(audioQueuebuffer?.pointee.mAudioData,
               inputData,
               Int(numberBytes))
        AudioQueueEnqueueBuffer(audioQueue,
                                audioQueuebuffer!,
                                numberPackets,
                                packetDescriptions)
        audioPlayerSelfPointer.state = .prepared
        AudioQueuePrime(audioQueue, 5, nil)
        AudioQueueStart (audioQueue, nil)

        }
    
    private var audioQueuePropertyListner: AudioQueuePropertyListenerProc = { (clientData,
        audioQueueRef,
        propertyID) in
        
        let audioPlayerSelfPointer: AudioPlayer = unsafeBitCast(clientData,
                                                                to: AudioPlayer.self)
        guard propertyID == kAudioQueueProperty_IsRunning else { return }
        
            var isRunning: UInt32 = 0
            var propertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        
            assertDependOnMultiMediaValueStatus(
                AudioQueueGetProperty(audioQueueRef,
                propertyID,
                &isRunning,
                &propertySize)
            )
        
        audioPlayerSelfPointer.isRunning = isRunning
        
    }
    
    private var outputListner: AudioQueueOutputCallback = { (clientData,
        audioQueue,
        buffer) -> Void in
        let audioPlayer = Unmanaged<AudioPlayer>.fromOpaque(clientData!).takeUnretainedValue()
        AudioQueueFreeBuffer(audioQueue, buffer)
    }
    
    var volume: Float = 3.0 {
        didSet {
            if let audioQueue = audioQueue {
                assertDependOnMultiMediaValueStatus(
                    AudioQueueSetParameter(audioQueue,
                    AudioQueueParameterID(kAudioQueueParam_Volume),
                    Float32(volume))
                )
            }
        }
    }
    
    init(data: Data) {
        self.passedData = data
        super.init()
        let audioPlayerSelfPointer = unsafeBitCast(self,
                                                   to: UnsafeMutableRawPointer.self)
        assertDependOnMultiMediaValueStatus(
            AudioFileStreamOpen(audioPlayerSelfPointer,
            propertyListener,
            packetInformationListner,
            kAudioFileAAC_ADTSType,
            &fileStreamID)
        )
        parse()
    }
    
    deinit {
        guard let audioQueue = audioQueue,
        let fileId = fileStreamID else { return }
        AudioQueueReset(audioQueue)
        AudioFileStreamClose(fileId)
    }
    
    func play() {
        
        guard let audioQueue = audioQueue else { return }
        
        AudioQueueStart(audioQueue,nil)
    }
    
    func pause() {
       guard let audioQueue = audioQueue else { return }
        assertDependOnMultiMediaValueStatus(
            AudioQueuePause(audioQueue)
        )
    }
    
    private func makeNewAudioQueue(_ audioStreamDescription: AudioStreamBasicDescription) {
        
        var mutableAudioStreamDescription = audioStreamDescription
        streamDescription = mutableAudioStreamDescription
        let audioPlayerSelfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        assertDependOnMultiMediaValueStatus(
            AudioQueueNewOutput(&mutableAudioStreamDescription,
                                outputListner,
                                audioPlayerSelfPointer,
                                CFRunLoopGetCurrent(),
                                CFRunLoopMode.commonModes.rawValue,
                                0,
                                &audioQueue)
            )
        
        guard let audioQueue = self.audioQueue else { return }
        
        assertDependOnMultiMediaValueStatus(
            AudioQueueAddPropertyListener(audioQueue,
                                          kAudioQueueProperty_IsRunning,
                                          audioQueuePropertyListner,
                                          audioPlayerSelfPointer)
            )

        AudioQueueStart(audioQueue, nil)
    }
    
    func parseDeliveredData() {
        var parseFlags: AudioFileStreamParseFlags
            //if state == .paused {
              //  parseFlags = .discontinuity
            //} else {
                guard let fileId = fileStreamID else { return }
                parseFlags = AudioFileStreamParseFlags(rawValue: 0)
                assertDependOnMultiMediaValueStatus(AudioFileStreamParseBytes(fileId,
                                                       UInt32(passedData.count),
                                                       (passedData as NSData).bytes,
                                                       parseFlags)
                )
           // }
        }
    
    
    
}

