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

    var track: Track { get }
    
    var videoDelegate: MultiMediaVideoTypeDecoderDelegate? { get set }
    var audioDelegate: MultiMediaAudioTypeDecoderDelegate? { get set }
    
    func decodeTrack(samples frames: [[UInt8]], pts: [Int])

    
}
