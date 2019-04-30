//
//  AsynFileReader.swift
//  MPEG-4Parser
//
//  Created by bumslap on 27/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

/* -> autorelease ??
 I couldn't find any official documentation of those new attributes (it's probably being worked on), but given the existing GCD documentation, and reading between the lines, it's pretty easy to intuit what's intended here.
 
 In the new DispatchQueue.Attributes, .serial is no longer a member. Does this mean that the absence of .concurrent creates a serial queue. An initial test I did in Swift Playgrounds seems to confirm this. Can anyone else confirm?
 Yes. A queue is either serial or concurrent. Most queues you create will be serial, so you only need to set them to be concurrent if you don't want the default behavior.
 
 I see that DispatchQueue.AutoreleaseFrequency is a new type with .inherit, .never, and .workItem. What do these mean? I did some research on GCD and autoreleasing but I'm not very familiar with the concept of autorelease pools.
 Previously, DispatchQueues would pop their autorelease pools at unspecified times (when the thread became inactive). In practice, this meant that you either created an autorelease pool for each dispatch item you submitted, or your autoreleased objects would hang around for an unpredictable amount of time.
 
 Non-determinism is not a great thing to have (particularly in a concurrency library!), so they now allow you to specify one of three behaviors:
 
 .inherit: Not sure, probably the previously-default behavior
 
 .workItem: Create and drain an autorelease pool for each item that gets executed
 
 .never: GCD doesn't manage autorelease pools for you
 
 Out of all of these, you're likely only going to want to use .workItem, because it'll clean up your temporary objects when the item completes. The other options are presumably for either buggy code that depends on the old behavior, or for that rare user that actually wants to manage this stuff themselves.
 
 Actually, thinking about it a bit more, if you're submitting work items that are Swift-only (they don't call into any Objective-C code), then .never is probably safe & correct. Given that any/all Swift standard library classes might call some Objective-C code, you'd probably want to limit this to computations which reside entirely within your own Swift code.
 
 */

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
        readQueue.sync {[weak self] in
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
    
    func hasAvailableData() -> Bool {
        if fileHandler.hasMoreData() {
            return true
        } else {
            return false
        }
    }
    
    func currentOffset() -> UInt64 {
        return fileHandler.offsetInFile
    }
        
}
