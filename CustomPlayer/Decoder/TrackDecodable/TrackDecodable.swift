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
    func decodeTrack(timeScale: Int)
}

protocol AudioTrackDecodable: TrackDecodable {
     var audioDelegate: MultiMediaAudioTypeDecoderDelegate? { get set }
}

protocol VideoTrackDecodable: TrackDecodable {
     var videoDelegate: MultiMediaVideoTypeDecoderDelegate? { get set }
}
