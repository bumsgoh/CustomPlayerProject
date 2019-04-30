//
//  VideoDecoderDelegate.swift
//  H264Player
//
//  Created by USER on 23/04/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
import VideoToolbox

protocol VideoDecoderDelegate: class {
    func shouldUpdateVideoLayer(with buffer: CMSampleBuffer)
}
