//
//  VideoFrameReader.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol VideoFrameReadable {
    
    var streamBuffer: [UInt8] { get set }
    var fileStream: InputStream? { get set }
    
    func open(url: URL)
    
    func extractFrame() -> [UInt8]?
    
    func readStream() -> Int
}

enum VideoCodec {
    case h264
}

struct VideoCodingConstant {
    
    static let startCode: [UInt8] = [0,0,1]
    static let bufferCapacity = 1280 * 720
}
