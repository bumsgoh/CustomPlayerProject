//
//  NALUnit.swift
//  CustomPlayer
//
//  Created by USER on 04/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

enum NALType: UInt8 {
    case idr = 0x05
    case sps = 0x07
    case pps = 0x08
    case sei = 0x06
    case aud = 0x09
    case slice = 0x01
    case unspecified = 0x00
}
