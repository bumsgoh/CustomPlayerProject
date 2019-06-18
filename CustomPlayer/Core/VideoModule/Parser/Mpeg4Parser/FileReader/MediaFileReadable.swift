//
//  MediaFileReadable.swift
//  CustomPlayer
//
//  Created by USER on 08/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol MediaFileReadable {
    
    var status: MediaStatus { get }
    
    var fileReader: FileStreamReadable { get }
    
    var root: RootType { get }
    
    func parse()
}
