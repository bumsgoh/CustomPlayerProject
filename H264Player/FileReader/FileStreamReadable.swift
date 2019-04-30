//
//  FileStreamReadable.swift
//  MPEG-4Parser
//
//  Created by bumslap on 29/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

protocol FileStreamReadable {
    
    var fileHandler: FileHandle { get }

    func read(length: Int, completion: @escaping (Data)->()) 
    
    func seek(offset: UInt64)
    
    func hasAvailableData() -> Bool
    
    func currentOffset() -> UInt64
    
    func close()
}
