//
//  AudioPlayer.swift
//  CustomPlayer
//
//  Created by bumslap on 06/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AudioToolbox
import CoreMedia
import AVFoundation


class AudioPlayer: NSObject {
    
    @objc dynamic var isReady: Bool = false
    @objc dynamic var state: MediaStatus = .stopped

    private var streamDescription: AudioStreamBasicDescription?
    private var isRunning: UInt32 = 0
    private var isPlaying: Bool = false
    private var dataBuffer: [Data] = []
    private var currentIndex: Int = 0
    private var currentDuration = 0
    
    var packetDescriptions: [AudioStreamPacketDescription] = []
    var bufferTime: Int = 2
    var readIndex: Int = 0
    
   // private var passedData: Data
    
    
//    private lazy var parse = {
//        self.parseDeliveredData()
//    }
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
    
    private var packetPerSecond: Int {
        get {
            guard let description = streamDescription else { return 0 }
            let numberOfPackets = Int(description.mSampleRate / Float64(description.mFramesPerPacket))
            return numberOfPackets
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
    
          audioPlayerSelfPointer.makeNewAudioQueue(audioStreamDescription)
    
    }
    
    
   private var packetInformationListner: AudioFileStream_PacketsProc = { (clientData,
        numberBytes,
        numberPackets,
        inputData,
        packetDescriptions) -> Void in
        let audioPlayerSelfPointer: AudioPlayer = unsafeBitCast(clientData,
                                                                to: AudioPlayer.self)
        print(numberPackets)
        guard numberBytes > 1 else { return }
        for index in 0..<numberPackets {
            audioPlayerSelfPointer.appendBuffer(inputData, inPacketDescription: &packetDescriptions[Int(index)])
        }
        audioPlayerSelfPointer.enqueuePacket(with: audioPlayerSelfPointer.readIndex)
        audioPlayerSelfPointer.readIndex += audioPlayerSelfPointer.dataBuffer.count

    

    }

    private var outputListner: AudioQueueOutputCallback = { (clientData,
        audioQueue,
        buffer) -> Void in
        let audioPlayer = Unmanaged<AudioPlayer>.fromOpaque(clientData!).takeUnretainedValue()
        AudioQueueFreeBuffer(audioQueue, buffer)
    }
    
    var volume: Float = 1.0 {
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
    
    override init() {
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
    }
    
    deinit {
        guard let audioQueue = audioQueue,
        let fileId = fileStreamID else { return }
        AudioQueueReset(audioQueue)
        AudioFileStreamClose(fileId)
    }
    
    func playIfNeeded() {
        
        guard let audioQueue = audioQueue, !isPlaying else { return }
        isPlaying = true
        state = .playing
        let cookie = getMagicCookieForFileStream()
        setMagicCookieForQueue(cookie!)
        self.enqueuePacket(with: 200)
        AudioQueuePrime(audioQueue, 5, nil)
        AudioQueueStart(audioQueue,nil)
    }
    
    func pause() {
       guard let audioQueue = audioQueue else { return }
        isPlaying = false
        state = .paused
        assertDependOnMultiMediaValueStatus(
            AudioQueuePause(audioQueue)
        )
    }
    
    func seek(to time: TimeInterval) {
        guard let audioQueue = audioQueue else { return }
         AudioQueueStop(audioQueue, true)
        guard let description = streamDescription, let fileId = fileStreamID else { return }
        let packetDuration = floor(time / (Float64(description.mFramesPerPacket) / description.mSampleRate))
        var outDataByteOffset: Int64 = 0
        var flags: AudioFileStreamSeekFlags = AudioFileStreamSeekFlags(rawValue: 0)
        let status = AudioFileStreamSeek(fileId, Int64(packetDuration), &outDataByteOffset, &flags)
    
         let audioPlayerSelfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        AudioQueueStart(audioQueue,nil)

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

    }
    
    func enqueuePacket(with number: Int) {
        guard let audioQueue = audioQueue else { return }
        var audioQueuebuffer: AudioQueueBufferRef?
        var targetData = Array(dataBuffer[number...])
        var targetDescriptions = Array(packetDescriptions[number...])
        let descPointer = UnsafePointer<AudioStreamPacketDescription>(&targetDescriptions)
        
        let startOffset = targetDescriptions[0].mStartOffset - 7
        
        for index in 0..<targetDescriptions.count {
            targetDescriptions[index].mStartOffset -= startOffset
            targetDescriptions[index].mDataByteSize = UInt32(targetData[index].count) - 7
        }
        
        var numberOfBytes = 0
        targetData.forEach {
            numberOfBytes += $0.count
        }

        AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, UInt32(numberOfBytes), UInt32(targetDescriptions.count), &audioQueuebuffer)
 
        audioQueuebuffer?.pointee.mAudioDataByteSize = UInt32(numberOfBytes)
        
        let joinedData = Data(targetData.joined())
     
        joinedData.withUnsafeBytes { (byte) -> Void in
            memcpy(audioQueuebuffer?.pointee.mAudioData,
                   byte,
                   Int(numberOfBytes))
        }

        
        AudioQueueEnqueueBuffer(audioQueue,
                                audioQueuebuffer!,
                                UInt32(targetData.count),
                                descPointer)
        
        self.isReady = true
        AudioQueueFreeBuffer(audioQueue, audioQueuebuffer!)
        
    }

    func appendBuffer(_ inInputData:UnsafeRawPointer,
                       inPacketDescription:inout AudioStreamPacketDescription) {
        
        let offset:Int = Int(inPacketDescription.mStartOffset)
        let packetSize:UInt32 = inPacketDescription.mDataByteSize
        inPacketDescription.mStartOffset = Int64(offset)
       
        packetDescriptions.append(inPacketDescription)
        dataBuffer.append(Data(bytes: inInputData + offset - 7, count: Int(packetSize + 7)))
        
     
    }
    
    func parseDeliveredData(data: Data) {
        var parseFlags: AudioFileStreamParseFlags
            //if state == .paused {
              //  parseFlags = .discontinuity
            //} else {
                guard let fileId = fileStreamID else { return }
                parseFlags = AudioFileStreamParseFlags(rawValue: 0)
                assertDependOnMultiMediaValueStatus(AudioFileStreamParseBytes(fileId,
                                                       UInt32(data.count),
                                                       (data as NSData).bytes,
                                                       parseFlags)
                )
    }
    
    
    func getMagicCookieForFileStream() -> [UInt8]? {
        guard let fileStreamID:AudioFileStreamID = fileStreamID else {
            return nil
        }
        var size:UInt32 = 0
        var writable:DarwinBoolean = true
        guard AudioFileStreamGetPropertyInfo(fileStreamID, kAudioFileStreamProperty_MagicCookieData, &size, &writable) == noErr else {
           
            return nil
        }
        var data:[UInt8] = [UInt8](repeating: 0, count: Int(size))
        guard AudioFileStreamGetProperty(fileStreamID, kAudioFileStreamProperty_MagicCookieData, &size, &data) == noErr else {
            
            return nil
        }
        return data
    }
    

    
    func setMagicCookieForQueue(_ inData: [UInt8]) -> Bool {
        guard let queue:AudioQueueRef = audioQueue else {
            return false
        }
        var status:OSStatus = noErr
        status = AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, inData, UInt32(inData.count))
        guard status == noErr else {
            
            return false
        }
        return true
    }
    
}

