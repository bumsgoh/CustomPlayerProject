//
//  AsynFileReader.swift
//  MPEG-4Parser
//
//  Created by bumslap on 27/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

class FileReader: FileStreamReadable {
    
    let fileHandler: FileHandle
    
    init?(url: URL) {
        guard let handler = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        self.fileHandler = handler
    }
    
    func read(length: Int) -> Data {
        return fileHandler.readData(ofLength: length)
    }
    
    func seek(offset: UInt64) {
        fileHandler.seek(toFileOffset: offset)
    }
    
    
    func close() {
        fileHandler.closeFile()
    }
    
    func currentOffset() -> UInt64 {
        return fileHandler.offsetInFile
    }
        
}
