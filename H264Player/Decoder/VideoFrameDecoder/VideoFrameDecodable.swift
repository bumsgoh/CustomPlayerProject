//
//  VideoFrameDecodable.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AVFoundation

protocol VideoFrameDecodable {
    
    var layer: AVSampleBufferDisplayLayer { get set }
    var track: Track { get set }
    var spsSize: Int { get set }
    var ppsSize: Int { get set }
    
    var sps: [UInt8]? { get set }
    var pps: [UInt8]? { get set }
    
    var videoFrameReader: VideoFrameReadable { get set }
    
    func decodeFile(url: URL)
    func decodeTrack(frames: [[UInt8]])
    
}
