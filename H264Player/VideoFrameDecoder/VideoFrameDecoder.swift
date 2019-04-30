//
//  VideoFrameDecoder.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

class VideoFrameDecoder: VideoFrameDecodable {
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    var spsSize: Int = 0
    var ppsSize: Int = 0
    
    var sps: [UInt8]?
    var pps: [UInt8]?
    
    var videoFrameReader: VideoFrameReadable
    
    weak var videoDecoderDelegate: VideoDecoderDelegate?
    
    init(videoFrameReader: VideoFrameReadable) {
        self.videoFrameReader = videoFrameReader
    }
    //240 2 00 00
    
    func decodeFile(url: URL) {
       
        videoFrameReader.open(url: url)
        
        while var packet = videoFrameReader.extractFrame() {
            analyzeNALAndDecode(videoPacket: &packet)
        }
    }
    
    private func analyzeNALAndDecode(videoPacket: inout VideoPacket) {
        
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(videoPacket.count - 4)))
       
        //print("before\(videoPacket)")
        memcpy(&videoPacket, &lengthOfNAL, 4)
        //print(videoPacket)
        let typeOfNAL = videoPacket[4] & 0x1F
        
        switch typeOfNAL {
        case TypeOfNAL.idr.rawValue:
            if buildDecompressionSession() {
                decodeVideoPacket(videoPacket: videoPacket)
            }
        case TypeOfNAL.sps.rawValue:
            spsSize = videoPacket.count - 4
            sps = Array(videoPacket[4..<videoPacket.count])
        case TypeOfNAL.pps.rawValue:
            ppsSize = videoPacket.count - 4
            pps = Array(videoPacket[4..<videoPacket.count])
        default:
            decodeVideoPacket(videoPacket: videoPacket)
            break
        }
    }

    private func decodeVideoPacket(videoPacket: VideoPacket) {
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: videoPacket)
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: bufferPointer,
                                                        blockLength: videoPacket.count,
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: videoPacket.count,
                                                        flags: 0,
                                                        blockBufferOut: &blockBuffer)
        if status != kCMBlockBufferNoErr {
            return
        }
        
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = [videoPacket.count]
        
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
            let session = decompressionSession,
            status == kCMBlockBufferNoErr else {
               // print("no session")
                return
        }
        ///공부해야함
        guard let attachments: CFArray =
            CMSampleBufferGetSampleAttachmentsArray(buffer,
                                                    createIfNecessary: true)
            else { return }
        
        let attributes = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                       to: CFMutableDictionary.self)
        CFDictionarySetValue(attributes,
                             Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                             Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        
        self.videoDecoderDelegate?.shouldUpdateVideoLayer(with: buffer)
    
        
        var flag = VTDecodeInfoFlags(rawValue: 0)
        var outputBuffer = UnsafeMutablePointer<CVPixelBuffer>.allocate(capacity: 1)
        
        status = VTDecompressionSessionDecodeFrame(session,
                                                   sampleBuffer: buffer,
                                                   flags: [._EnableAsynchronousDecompression],
                                                   frameRefcon: &outputBuffer,
                                                   infoFlagsOut: &flag)
        switch status {
        case noErr:
            print("ok")
        case kVTInvalidSessionErr:
            print("invalid")
        case kVTVideoDecoderBadDataErr:
            print("badData")
        default:
            print("\(status)")
        }
    }
    
    
    private func buildDecompressionSession() -> Bool {
        formatDescription = nil
        
        guard let spsData = sps, let ppsData = pps else {
            print("param fail")
            return false
        }
        let spsPointer = UnsafePointer<UInt8>(spsData)
        let ppsPointer = UnsafePointer<UInt8>(ppsData)
        
        let parameters = [spsPointer, ppsPointer]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(parameters)
        
        let sizeOfParameters = [spsData.count, ppsData.count]
        let sizeOfparameterSet = UnsafePointer<Int>(sizeOfParameters)
        
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                         parameterSetCount: 2,
                                                                         parameterSetPointers: parameterSetPointers,
                                                                         parameterSetSizes: sizeOfparameterSet,
                                                                         nalUnitHeaderLength: 4,
                                                                         formatDescriptionOut: &formatDescription)
        guard let formatDescription = self.formatDescription,
            status == noErr
            else {
                print("desc fail")
            return false
        }
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        var localSession: VTDecompressionSession?
        
        let decoderParameters = NSMutableDictionary()
        let decoderPixelBufferAttributes = NSMutableDictionary()
        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
        var outputCallback = VTDecompressionOutputCallbackRecord()
        
        outputCallback.decompressionOutputCallback = nil
        
        outputCallback.decompressionOutputRefCon =
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                  formatDescription: formatDescription,
                                                  decoderSpecification: decoderParameters,
                                                  imageBufferAttributes: decoderPixelBufferAttributes,
                                                  outputCallback: &outputCallback,
                                                  decompressionSessionOut: &localSession)
        if sessionStatus != noErr {
            assertionFailure("decomp Error")
        }
        decompressionSession = localSession
        return true
        
        
    }
    
    private func decompressionSessionDecodeFrameCallback(_ decompressionOutputRefCon: UnsafeMutableRawPointer?, _ sourceFrameRefCon: UnsafeMutableRawPointer?, _ status: OSStatus, _ infoFlags: VTDecodeInfoFlags, _ imageBuffer: CVImageBuffer?, _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime) {
        
        let streamer: PlayerViewContoller = unsafeBitCast(decompressionOutputRefCon,
                                                          to: PlayerViewContoller.self)
        if status != noErr {
            print("hi")
        }
    }

}

enum TypeOfNAL: UInt8 {
    case idr = 0x05
    case sps = 0x07
    case pps = 0x08
    case bpFrame
}
