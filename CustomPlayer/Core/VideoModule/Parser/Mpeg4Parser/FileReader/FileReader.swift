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
    let readQueue: DispatchQueue = DispatchQueue.global(qos: .default)
    
    init?(url: URL) {
        guard let handler = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        self.fileHandler = handler
    }
    
    func read(length: Int, completion: @escaping (Data)->()) {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            let data = self.fileHandler.readData(ofLength: length)
            completion(data)
        }
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
