//
//  VideoFrameDecoder.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox


class VideoTrackDecoder: NSObject, TrackDecodable {
    
    private(set) var track: Track
    
    private var isPrepared: Bool = false
    
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    
    private var spsSize: Int = 0
    private var ppsSize: Int = 0
    
    private var sps: [UInt8] = []
    private var pps: [UInt8] = []

    
    var sampleBuffers: CMSampleBuffer? = nil {
        didSet {
            
                isPrepared = true
                videoDelegate?.prepareToDisplay(with: sampleBuffers!)
        }
    }
    
    private var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    weak var videoDelegate: MultiMediaVideoTypeDecoderDelegate?
    weak var audioDelegate: MultiMediaAudioTypeDecoderDelegate? = nil
    
    
    private var dataPackage: DataPackage
    
    
    init(track: Track, dataPackage: DataPackage) {
        self.track = track
        self.dataPackage = dataPackage
    }
    
    private var callback: VTDecompressionOutputCallback = {(
        decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVBuffer?,
        presentationTimeStamp: CMTime,
        duration: CMTime) in
        
        let decoder: VideoTrackDecoder = unsafeBitCast(decompressionOutputRefCon,
                                                       to: VideoTrackDecoder.self)
        guard let decodedBuffer = imageBuffer else { return }
        
        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid
        )
        
        var formatDescription: CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: decodedBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        var decodedSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: decodedBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &decodedSampleBuffer
        )
        
        decoder.videoDelegate?.prepareToDisplay(with: decodedSampleBuffer!)
    }
    
    func decodeTrack(timeScale: Int) {
        print(timeScale)
        var timingInfos: [CMSampleTimingInfo] = []
        var count = 0
        for pts in dataPackage.presentationTimestamp {
            let composionTimestamp = track.samples[count].compositionTimeOffset
            timingInfos.append(CMSampleTimingInfo(duration: CMTime(value: 0, timescale: 0),
                                                  presentationTimeStamp: CMTime(value: CMTimeValue(pts + composionTimestamp),
                                                                                timescale: CMTimeScale(timeScale)),
                                                  decodeTimeStamp: CMTime(value: 0, timescale: 0)))
            count += 1
        }
        
        buildDecompressionSession()
        decodeVideoPacket(timingInfos: timingInfos)
        
    }
    
    
    private func decodeVideoPacket(timingInfos: [CMSampleTimingInfo]) {
        var blockBuffer: CMBlockBuffer?
        let dataLength = dataPackage.dataStorage.map {
            $0.count
            }.reduce(0, {$0 + $1})
        
        let sizeArray = dataPackage.dataStorage.map {
            $0.count
        }
        var mergedData = Data(dataPackage.dataStorage.joined())
        mergedData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: bytes,
            blockLength: dataLength,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataLength,
            flags: 0,
            blockBufferOut: &blockBuffer) == kCMBlockBufferNoErr else {
                return
                                                            
            }
        }
      
        
        var sampleBuffer: CMSampleBuffer?
        var timingEntries = dataPackage.presentationTimestamp.count

        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: sizeArray.count,
            sampleTimingEntryCount: timingEntries,
            sampleTimingArray: timingInfos,
            sampleSizeEntryCount: sizeArray.count,
            sampleSizeArray: sizeArray,
            sampleBufferOut: &sampleBuffer) == kCMBlockBufferNoErr,
            let derivedSampleBuffer = sampleBuffer else {
            return
        }
        guard let session = decompressionSession else {
                print("failed to fetch session")
                return
        }
        
        var flag = VTDecodeInfoFlags()
   
        let st = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: derivedSampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            frameRefcon: nil,
            infoFlagsOut: &flag)
        print(st)
        
    }
    
    private func buildDecompressionSession() {
        
        formatDescription = nil
        
        let spsData = track.sequenceParameters.toUInt8Array
        let ppsData = track.pictureParameters.toUInt8Array
        let spsPointer = UnsafePointer<UInt8>(Array(spsData))
        let ppsPointer = UnsafePointer<UInt8>(Array(ppsData))
        
        let parameters = [spsPointer, ppsPointer]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(parameters)
        
        let sizeParamArray = [spsData.count, ppsData.count]
        let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                         parameterSetCount: 2,
                                                                         parameterSetPointers: parameterSetPointers,
                                                                         parameterSetSizes: parameterSetSizes,
                                                                         nalUnitHeaderLength: 4,
                                                                         formatDescriptionOut: &formatDescription)
        guard let formatDescription = formatDescription,
            status == noErr else {
                assertionFailure("format Desc failed")
                return
        }
        
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        
        var localSession: VTDecompressionSession?
        
        let decoderParameters = NSMutableDictionary()
        let decoderPixelBufferAttributes = NSMutableDictionary()
        decoderPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        
       
        var didSessionCreate:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        )
        
        let sessionStatus = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                  formatDescription: formatDescription,
                                                  decoderSpecification: decoderParameters,
                                                  imageBufferAttributes: decoderPixelBufferAttributes,
                                                  outputCallback: &didSessionCreate,
                                                  decompressionSessionOut: &localSession)
        if sessionStatus != noErr {
            assertionFailure("decomp Error")
        }
        
        decompressionSession = localSession
    }
    
    private func analyzeNALAndDecode(videoPacket: inout [UInt8]) {
        
        var lengthOfNAL = CFSwapInt32HostToBig((UInt32(videoPacket.count - 4)))
        
        memcpy(&videoPacket, &lengthOfNAL, 4)
        let typeOfNAL = videoPacket[4] & 0x1F
        
        switch typeOfNAL {
        case TypeOfNAL.idr.rawValue:
            buildDecompressionSession()
          //      decodeVideoPacket(videoPacket: videoPacket)
            
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
