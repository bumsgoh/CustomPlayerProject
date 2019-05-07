//
//  TrackDecodable.swift
//  CustomPlayer
//
//  Created by USER on 03/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import AVFoundation

protocol TrackDecodable: class {
    var mediaReader: MediaFileReader? { get set }
    var track: Track { get set }
    var delegate: MultiMediaDecoderDelegate? { get set }
    func decodeTrack(samples frames: [[UInt8]], pts: [Int])
    func play()
    
}
