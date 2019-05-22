//
//  PlaybackList.swift
//  CustomPlayer
//
//  Created by bumslap on 19/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class MasterPlaylist {
    var version: Int = 0
    var bandWidth: Int = 0
    var frameRate: Float = 0
    var hdcpLevel: String = "TYPE-0"
    var resolution: String = ""
    var videoRange: Int = 0
    var codecs: [String] = []
    var path: String = ""
    
    var mediaPlaylists: [MediaPlaylist] = []
 
}


