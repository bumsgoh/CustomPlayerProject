//
//  VideoFrameReader.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class VideoFrameReader: VideoFrameReadable {
    var streamBuffer: [UInt8] = []
    
    var fileStream: InputStream?
    
    func open(url: URL) {
        fileStream = InputStream(url: url)
        fileStream?.open()
    }
    
    func extractFrame() -> VideoPacket? {
        var startIndex = 4
        
        if streamBuffer.isEmpty && readStream() == 0 {
            return nil
        }
        
        if streamBuffer.count < 5 || Array(streamBuffer[0...3]) != VideoCodingConstant.startCode {
            return nil
        }
        
        while true {
            while (startIndex + 3) < streamBuffer.count {
                if Array(streamBuffer[startIndex...startIndex + 3]) == VideoCodingConstant.startCode {
                    let packet = Array(streamBuffer[0..<startIndex])
                    streamBuffer.removeSubrange(0..<startIndex)
                    return packet
                }
                startIndex += 1
            }
            
            if readStream() == 0 {
                return nil
            }
        }
        
    }
    
    func readStream() -> Int {
        guard let stream = fileStream, stream.hasBytesAvailable else {
            return 0
        }
        
        var tempBuffer = [UInt8].init(repeating: 0,
                                      count: VideoCodingConstant.bufferCapacity)
        let bytes = stream.read(&tempBuffer,
                                maxLength: VideoCodingConstant.bufferCapacity)
        if bytes > 0 {
            streamBuffer.append(contentsOf: Array(tempBuffer[0..<bytes]))
            return bytes
        }
        
        return 0
    }
    
    
}

