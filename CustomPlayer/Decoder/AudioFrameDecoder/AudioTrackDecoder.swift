//
//  AudioFrameDecoder.swift
//  H264Player
//
//  Created by USER on 02/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import CoreMedia
import AudioToolbox

class AudioTrackDecoder: TrackDecodable {
   var audioFileStreamID: AudioFileStreamID? = nil
    var videoDelegate: MultiMediaVideoTypeDecoderDelegate? = nil
    
    var audioDelegate: MultiMediaAudioTypeDecoderDelegate?
    
    private(set) var presentationTimestamp: [Int]
    private(set) var track: Track
    private(set) var samples: [[UInt8]]
    private var derivedData: Data = Data()
    
    private var isPrepared: Bool = false
    
    var streamPropertyListenerProc: AudioFileStream_PropertyListenerProc = { (clientData, audioFileStreamID, propertyID, ioFlags) -> Void in
  
        let this = Unmanaged<AudioTrackDecoder>.fromOpaque(clientData).takeUnretainedValue()
        if propertyID == kAudioFileStreamProperty_DataFormat {
            var status: OSStatus = 0
            var dataSize: UInt32 = 0
            var writable: DarwinBoolean = false
            status = AudioFileStreamGetPropertyInfo(audioFileStreamID, kAudioFileStreamProperty_DataFormat, &dataSize, &writable)
            assert(noErr == status)
            var audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()
            status = AudioFileStreamGetProperty(audioFileStreamID, kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription)
            assert(noErr == status)
            print(audioStreamDescription)
            print("_---------")
            print(this.getMagicCookieForFileStream())
            print(this.getFormatDescriptionForFileStream())
            print(kAudioFileStreamProperty_MagicCookieData)
            //self.formatDescription = audioStreamDescription
            }
        }
    
    init(track: Track, samples: [[UInt8]], presentationTimestamp: [Int]) {
        self.track = track
        self.samples = samples
        self.presentationTimestamp = presentationTimestamp
        let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
       let status =  AudioFileStreamOpen(selfPointer, streamPropertyListenerProc, AudioFileStreamPacketsCallback, kAudioFileAAC_ADTSType, &self.audioFileStreamID)
        print(status)
        
        callback()
    }
    
    func decodeTrack(samples frames: [[UInt8]], pts: [Int])  {
        var mergedData = Data()
        var sizeArray: [Int] = []
        samples.forEach {
           mergedData.append($0.tohexNumbers
                .mergeToString
                .convertHexStringToData
                .addADTS
            )
          sizeArray.append($0.count + 7)
        }
        self.derivedData = mergedData
        var timingInfos: [CMSampleTimingInfo] = []
        
        for i in pts {
            timingInfos.append(CMSampleTimingInfo(duration: CMTime(value: 0, timescale: 0), presentationTimeStamp: CMTime(value: CMTimeValue(i), timescale: 44100), decodeTimeStamp: CMTime(value: 0, timescale: 0)))
        }
        
        
        audioDelegate?.prepareToPlay(with: mergedData)
    }
    
    func fetchSampleBuffer(timingInfos: [CMSampleTimingInfo], sizeArray: [Int]) -> CMSampleBuffer? {
        let dataPointer = UnsafeMutablePointer<Data>(&derivedData)
      //  let buffer = AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(derivedData.count), mData: dataPointer)

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: dataPointer,
                                                        blockLength: derivedData.count,
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: derivedData.count,
                                                        flags: 0,
                                                        blockBufferOut: &blockBuffer)
        if status != kCMBlockBufferNoErr {
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = sizeArray
        let timingInfos = timingInfos
        
        /*  let timingInfo = [CMSampleTimingInfo(duration: CMTime(value: 0, timescale: 0), presentationTimeStamp: CMTime(value: Int64(pts), timescale: 24000), decodeTimeStamp: CMTime(value: 0, timescale: 0))]
         CMSampleBufferCreate*/
        let formatDescription = createCMAudioFormatDescription()
        
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                               dataBuffer: blockBuffer,
                                               formatDescription: formatDescription,
                                               sampleCount: sampleSizeArray.count,
                                               sampleTimingEntryCount: timingInfos.count,
                                               sampleTimingArray: timingInfos,
                                               sampleSizeEntryCount: sampleSizeArray.count,
                                               sampleSizeArray: sampleSizeArray,
                                               sampleBufferOut: &sampleBuffer)
        guard let derivedBuffer = sampleBuffer,
            status == kCMBlockBufferNoErr else {
                print("no session")
                return nil
        }
        
        
        return derivedBuffer
    }
    
    func createCMAudioFormatDescription() -> CMAudioFormatDescription {
        var asbd = AudioStreamBasicDescription(mSampleRate: 44100.0,
                                               mFormatID: kAudioFormatMPEG4AAC,
                                               mFormatFlags: 0,
                                               mBytesPerPacket: 0,
                                               mFramesPerPacket: 1024,
                                               mBytesPerFrame: 0,
                                               mChannelsPerFrame: 2,
                                               mBitsPerChannel: 0,
                                               mReserved: 0)
        var formatDescription:CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                       asbd: &asbd,
                                       layoutSize: 0,
                                       layout: nil,
                                       magicCookieSize: 0,
                                       magicCookie: nil,
                                       extensions: nil,
                                       formatDescriptionOut: &formatDescription)
        print(formatDescription)
        return formatDescription!
    }
    
    func callback() {
        var parseFlags: AudioFileStreamParseFlags
            parseFlags = AudioFileStreamParseFlags(rawValue: 0)
        let status = AudioFileStreamParseBytes(self.audioFileStreamID!, UInt32(derivedData.count), (derivedData as NSData).bytes, parseFlags)
            if status == noErr {
                print("parse succeed")
            }
        }
    
    func getFormatDescriptionForFileStream() -> AudioStreamBasicDescription? {
        guard let fileStreamID:AudioFileStreamID = self.audioFileStreamID else {
            return nil
        }
        var data:AudioStreamBasicDescription = AudioStreamBasicDescription()
        var size:UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioFileStreamGetProperty(fileStreamID, kAudioFileStreamProperty_DataFormat, &size, &data) == noErr else {
         
            return nil
        }
        return data
    }
    
    func getMagicCookieForFileStream() -> [UInt8]? {
        guard let fileStreamID:AudioFileStreamID = self.audioFileStreamID else {
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
    }

    
    func AudioFileStreamPropertyListenerCallback(_ clientData: UnsafeMutableRawPointer, audioFileStream: AudioFileStreamID, propertyID: AudioFileStreamPropertyID, ioFlag: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
        let this = Unmanaged<AudioTrackDecoder>.fromOpaque(clientData).takeUnretainedValue()
        if propertyID == kAudioFileStreamProperty_DataFormat {
            var status: OSStatus = 0
            var dataSize: UInt32 = 0
            var writable: DarwinBoolean = false
            status = AudioFileStreamGetPropertyInfo(audioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &writable)
            assert(noErr == status)
            var audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()
            status = AudioFileStreamGetProperty(audioFileStream, kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription)
            assert(noErr == status)
            print(audioStreamDescription)
            print("_---------")
            print(this.getMagicCookieForFileStream())
            print(this.getFormatDescriptionForFileStream())
            print(kAudioFileStreamProperty_MagicCookieData)
            //self.formatDescription = audioStreamDescription
        }
    }
    
    func AudioFileStreamPacketsCallback(_ clientData: UnsafeMutableRawPointer, numberBytes: UInt32, numberPackets: UInt32, ioData: UnsafeRawPointer, packetDescription: UnsafeMutablePointer<AudioStreamPacketDescription>) {

    }

    

