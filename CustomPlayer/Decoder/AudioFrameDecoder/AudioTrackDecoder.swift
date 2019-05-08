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
    func decodeTrack(samples frames: [[UInt8]], pts: [Int]) {
        
    }
    
    func decodeTrack(samples frames: [[UInt8]], pts: Int) {
        
    }
    
    
    var track: Track
    weak var delegate: MultiMediaDecoderDelegate?
    var mediaReader: MediaFileReader?
    
    init(track: Track) {
        self.track = track
    }
    
    func createAudioFormatDescription() -> CMAudioFormatDescription? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 0,
            mReserved: 0)
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(allocator: nil,
                                       asbd: &asbd,
                                       layoutSize: 0,
                                       layout: nil,
                                       magicCookieSize: 0,
                                       magicCookie: nil,
                                       extensions: nil,
                                       formatDescriptionOut: &formatDescription)
        
        print(formatDescription)
        
        return formatDescription
    }
    
    func decodeTrack(samples: [[UInt8]]) {

        for packet in samples {
            let mutablePacks = packet
            decodeAudioPacket(audioSample: mutablePacks)
        }
    }
    
    func decodeAudioPacket(audioSample: [UInt8]) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: audioSample)
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: bufferPointer,
                                                        blockLength: audioSample.count,
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: audioSample.count,
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
        
        guard let formatDescription = createAudioFormatDescription() else {
            assertionFailure("formatDesc Failed")
            return
        }

     
        let sampleSizeArray = [audioSample.count]
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: blockBuffer,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: formatDescription,
                                      sampleCount: 1,
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: sampleSizeArray,
                                      sampleBufferOut: &sampleBuffer)
        
        guard status == noErr else {
            return
        }
        guard let buffer = sampleBuffer,
            status == kCMBlockBufferNoErr else {
                assertionFailure("buffer failed")
                return
        }
        delegate?.shouldUpdateLayer(with: buffer)
    }
    
    func play() {
        var frames: [[UInt8]] = []
        for sample in track.samples {
            
            mediaReader?.fileReader.seek(offset: UInt64(sample.offset))
            mediaReader?.fileReader.read(length: sample.size) { (data) in
                frames.append(Array(data))
            }
        }
        
        decodeTrack(samples: frames)
    }
}
