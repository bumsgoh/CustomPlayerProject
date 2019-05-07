//
//  VideoFrameDecoder.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox
import AVFoundation

class VideoTrackDecoder: TrackDecodable {
    var mediaReader: MediaFileReader?
    var samples: [CMSampleBuffer] = []
    var currentTime: CMTime?
    var time: CMTime = CMTime(value: 1, timescale: 24)
    var track: Track = Track()
    var count = 0
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    var spsSize: Int = 0
    var ppsSize: Int = 0
    
    var sps: [UInt8]?
    var pps: [UInt8]?
    
    var videoFrameReader: VideoFrameReadable
    
    weak var delegate: MultiMediaDecoderDelegate?
    var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    init(videoFrameReader: VideoFrameReadable) {
        self.videoFrameReader = videoFrameReader
    }
    
    fileprivate var callback:VTDecompressionOutputCallback = {(
        decompressionOutputRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTDecodeInfoFlags,
        imageBuffer:CVBuffer?,
        presentationTimeStamp:CMTime,
        duration:CMTime) in
        let decoder: VideoTrackDecoder = unsafeBitCast(decompressionOutputRefCon, to: VideoTrackDecoder.self)
        decoder.didOutputForSession(status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration)
    }
    
    func decodeFile(url: URL) {
       
        videoFrameReader.open(url: url)
        
        while var packet = videoFrameReader.extractFrame() {
            analyzeNALAndDecode(videoPacket: &packet)
        }
    }
    
    func decodeTrack(samples frames: [[UInt8]], pts: [Int]) {
        pps = track.pictureParams.toUInt8Array
        sps = track.sequenceParameters.toUInt8Array
        var count = 0
        let duration = pts[1] * pts.count
        
        buildDecompressionSession()
        for packet in frames {
            semaphore.wait()
                decodeVideoPacket(videoPacket: packet, pts: pts[count], duration: duration)
            count += 1
        }
        
    }
    

    private func decodeVideoPacket(videoPacket: [UInt8], pts: Int, duration: Int) {
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
//CMSampleBufferCreate(allocator: <#T##CFAllocator?#>, dataBuffer: <#T##CMBlockBuffer?#>, dataReady: <#T##Bool#>, makeDataReadyCallback: <#T##CMSampleBufferMakeDataReadyCallback?##CMSampleBufferMakeDataReadyCallback?##(CMSampleBuffer, UnsafeMutableRawPointer?) -> OSStatus#>, refcon: <#T##UnsafeMutableRawPointer?#>, formatDescription: <#T##CMFormatDescription?#>, sampleCount: <#T##CMItemCount#>, sampleTimingEntryCount: <#T##CMItemCount#>, sampleTimingArray: <#T##UnsafePointer<CMSampleTimingInfo>?#>, sampleSizeEntryCount: <#T##CMItemCount#>, sampleSizeArray: <#T##UnsafePointer<Int>?#>, sampleBufferOut: <#T##UnsafeMutablePointer<CMSampleBuffer?>#>)
        
        let timingInfo = [CMSampleTimingInfo(duration: CMTime(value: 0, timescale: 0), presentationTimeStamp: CMTime(value: Int64(pts), timescale: 24000), decodeTimeStamp: CMTime(value: 0, timescale: 0))]
        //self.time.value += Int64(pts)
        //count += 2
       // print("is timeinfo \(timingInfo.presentationTimeStamp)")
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                           dataBuffer: blockBuffer,
                                           formatDescription: formatDescription,
                                           sampleCount: 1,
                                           sampleTimingEntryCount: 1,
                                           sampleTimingArray: timingInfo,
                                           sampleSizeEntryCount: 1,
                                           sampleSizeArray: sampleSizeArray,
                                           sampleBufferOut: &sampleBuffer)
        guard let buffer = sampleBuffer,
            let session = decompressionSession,
            status == kCMBlockBufferNoErr else {
                print("no session")
                return
        }
        
       // print("here2")
        ///공부해야함
        guard let attachments: CFArray =
            CMSampleBufferGetSampleAttachmentsArray(buffer,
                                                    createIfNecessary: true)
            else { return }
        
        let attributes = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                       to: CFMutableDictionary.self)
        CFDictionarySetValue(attributes,
                             Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                             Unmanaged.passUnretained(kCFBooleanFalse).toOpaque())
       /* if layer.isReadyForMoreMediaData {
            self.delegate?.shouldUpdateLayer(with: buffer)
        }*/
        
        
        var flag = VTDecodeInfoFlags()
        
        status = VTDecompressionSessionDecodeFrame(session,
                                                   sampleBuffer: buffer,
                                                   flags: [._EnableAsynchronousDecompression,
                                                           ._EnableTemporalProcessing],
                                                   frameRefcon: nil,
                                                   infoFlagsOut: &flag)
        switch status {
        case noErr:
            let va = 1
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
        
        guard let spsData = sps, let ppsData =  pps else {
            print("param fail")
            return false
        }
        
        print("is \(spsData)")
        print("is \(ppsData)")
        let spsPointer = UnsafePointer<UInt8>(Array(spsData))
        let ppsPointer = UnsafePointer<UInt8>(Array(ppsData))
        
        let parameters = [spsPointer, ppsPointer]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(parameters)
        
        //let sizeOfParameters = [spsData.count, ppsData.count]
       // let sizeOfparameterSet = UnsafePointer<Int>(sizeOfParameters)
      
        
        let sizeParamArray = [spsData.count, ppsData.count]
//CMVideoFormatDescriptionRef
        let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                         parameterSetCount: 2,
                                                                         parameterSetPointers: parameterSetPointers,
                                                                         parameterSetSizes: parameterSetSizes,
                                                                         nalUnitHeaderLength: 4,
                                                                         formatDescriptionOut: &formatDescription)
        guard let formatDescription = self.formatDescription,
            status == noErr
            else {
                print("desc fail\(status)")
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
        
       // var outputCallback = VTDecompressionOutputCallbackRecord()
        
       // outputCallback.decompressionOutputCallback = nil
        
       // outputCallback.decompressionOutputRefCon =
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var record:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        )
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                  formatDescription: formatDescription,
                                                  decoderSpecification: decoderParameters,
                                                  imageBufferAttributes: decoderPixelBufferAttributes,
                                                  outputCallback: &record,
                                                  decompressionSessionOut: &localSession)
        if sessionStatus != noErr {
            assertionFailure("decomp Error")
        }
        decompressionSession = localSession
        return true
        
        
    }
    
    
    func didOutputForSession(_ status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBuffer?, presentationTimeStamp:CMTime, duration:CMTime) {
       
        guard let imageBuffer:CVImageBuffer = imageBuffer , status == noErr else {
            return
        }
        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime(value: 0, timescale: 0)
            
        )//kCMTimeInvalid
      //  print(duration)
        var videoFormatDescription:CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &videoFormatDescription
        )
        var sampleBuffer:CMSampleBuffer? = nil
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoFormatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard let buffer:CMSampleBuffer = sampleBuffer else {
            return
        }
        semaphore.signal()
        delegate?.shouldUpdateLayer(with: buffer)
    }
    
    private func analyzeNALAndDecode(videoPacket: inout [UInt8]) {
        
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(videoPacket.count - 4)))
        
        //print("before\(videoPacket)")
        memcpy(&videoPacket, &lengthOfNAL, 4)
        //print(videoPacket)
        let typeOfNAL = videoPacket[4] & 0x1F
        
        switch typeOfNAL {
        case TypeOfNAL.idr.rawValue:
            if buildDecompressionSession() {
          //      decodeVideoPacket(videoPacket: videoPacket)
            }
        case TypeOfNAL.sps.rawValue:
            spsSize = videoPacket.count - 4
            sps = Array(videoPacket[4..<videoPacket.count])
        case TypeOfNAL.pps.rawValue:
            ppsSize = videoPacket.count - 4
            pps = Array(videoPacket[4..<videoPacket.count])
        default:
         //   decodeVideoPacket(videoPacket: videoPacket)
            break
        }
    }


}

enum TypeOfNAL: UInt8 {
    case idr = 0x05
    case sps = 0x07
    case pps = 0x08
    case bpFrame
}
