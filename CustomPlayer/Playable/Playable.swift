//
//  Playable.swift
//  CustomPlayer
//
//  Created by bumslap on 08/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol Playable {
    var timescale: Int { get }
    var isPlayable: Bool { get }
    var status: MediaStatus { get }
    var tracks: [Track] { get }
}

@objc enum MediaStatus: Int {
    case stopped
    case paused
    case prepared
    case playing
}
