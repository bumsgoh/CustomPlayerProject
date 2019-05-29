//
//  MediaSegment.swift
//  CustomPlayer
//
//  Created by bumslap on 20/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class MediaSegment {
    var mediaPlaylist: MediaPlaylist?
    var duration: Float?
    var sequence: Int = 0
    var subrangeLength: Int?
    var subrangeStart: Int?
    var title: String?
    var discontinuity: Bool = false
    var path: String?
}
