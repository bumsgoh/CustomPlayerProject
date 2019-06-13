//
//  InterruptHandler.swift
//  CustomPlayer
//
//  Created by USER on 13/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

typealias InterruptHandler = (Interrupt) -> Void

enum Interrupt {
    case seek(Int)
    case multiTrackRequest(Int)
}
