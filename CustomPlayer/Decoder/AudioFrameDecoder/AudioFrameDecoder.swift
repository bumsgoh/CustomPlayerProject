//
//  AudioFrameDecoder.swift
//  H264Player
//
//  Created by USER on 02/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import CoreMedia

class AudioFrameDecoder {
    
    weak var videoDecoderDelegate: VideoDecoderDelegate?
    
    func createAudioFormatDescription() -> CMAudioFormatDescription? {
        var asbd = AudioStreamBasicDescription()
        
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked
        asbd.mSampleRate = 44100
        asbd.mBitsPerChannel = 32
        asbd.mFramesPerPacket = 1
        asbd.mChannelsPerFrame = 2
        asbd.mBytesPerFrame = asbd.mBitsPerChannel / 8 * asbd.mChannelsPerFrame
        asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket
        
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil,
                                       asbd: &asbd,
                                       layoutSize: 0,
                                       layout: nil,
                                       magicCookieSize: 0,
                                       magicCookie: nil,
                                       extensions: nil,
                                       formatDescriptionOut: &formatDescription)
        
        return formatDescription
    }
    
    func decodeTrack(frames: [[UInt8]]) {

        for packet in frames {
            let mutablePacks = packet
            decodeAudioPacket(audioPacket: mutablePacks)
        }
    }
    
    func decodeAudioPacket(audioPacket: VideoPacket) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: audioPacket)
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: bufferPointer,
                                                        blockLength: audioPacket.count,
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: audioPacket.count,
                                                        flags: 0,
                                                        blockBufferOut: &blockBuffer)
        if status != kCMBlockBufferNoErr {
            return
        }
        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(44100)),
            presentationTimeStamp: CMTime.zero,
            decodeTimeStamp: CMTime.invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = [audioPacket.count]
        guard let formatDescription = createAudioFormatDescription() else {
            assertionFailure("formatDesc Failed")
            return
        }
            
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                           dataBuffer: blockBuffer,
                                           formatDescription: formatDescription,
                                           sampleCount: 1,
                                           sampleTimingEntryCount: 0,
                                           sampleTimingArray: nil,
                                           sampleSizeEntryCount: 1,
                                           sampleSizeArray: sampleSizeArray,
                                           sampleBufferOut: &sampleBuffer)
        guard let buffer = sampleBuffer,
            status == kCMBlockBufferNoErr else {
                assertionFailure("buffer failed")
                return
        }
        
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: nil,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: formatDescription,
                                      sampleCount: 10,
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: nil,
                                      sampleBufferOut: &sampleBuffer)
        
        guard status == noErr else {
            return
        }
        
        videoDecoderDelegate?.shouldUpdateVideoLayer(with: buffer)
    }
}
