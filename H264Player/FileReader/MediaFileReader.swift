//
//  MediaFileReader.swift
//  MPEG-4Parser
//
//  Created by bumslap on 29/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

class MediaFileReader {
    let fileReader: FileStreamReadable
    let typeOfContainer: FileContainerType
    let containerPool: ContainerPool = ContainerPool()
    let root: RootType
    
    private let headerSize = 8
     private var fileOffset = 0
    
    init(fileReader: FileStreamReadable, type: FileContainerType) {
        self.fileReader = fileReader
        self.typeOfContainer = type
        let root = RootType()
        root.size = 9097807 + 8
        self.root = root
    }
    
    private func readHeader(completion: @escaping ((Int, String))->()) {
        fileReader.read(length: 8) {(data) in
            let result = self.converToHeaderInfo(data: data)
            completion(result)

        }
    }
    
    private func converToHeaderInfo(data: Data) -> (Int, String) {
        let sizeData = data.subdata(in: 0..<4)
        let size = sizeData.convertToInt
        guard let decodedHeaderName = String(data: data.subdata(in: 4..<8),
                                             encoding: .utf8) else {
                                                return (0,"")
        }
        fileOffset += 8
        return (size, decodedHeaderName)
    }
    
    func decodeFile(type: FileContainerType) {
        //TODO filetype 에 따라 다른 디코딩 방식제공해야함
        var containers: [HalfContainer] = []
        
        containers = decode(root: self.root)
        
        while var item = containers.first {
            containers.remove(at: 0)
            
            print("it\(item) and size\(item.size)")
            let parentContainers = decode(root: item)
            
            containers.append(contentsOf: parentContainers)
        }
        root.parse()
        
        print("________________________")
    }
    
    private func decode(root: HalfContainer) -> [HalfContainer] {
        var containers: [HalfContainer] = []
        var currentRootContainer: HalfContainer = root
        var currentOffset = currentRootContainer.offset
        var isfinished: Bool = false
        fileReader.seek(offset: currentOffset)
        var sizeOfChildren = 0
        var count = 0
       repeat {
            
        
            
            readHeader() { [weak self] (headerData) in
                guard let self = self else { return }
                let size = headerData.0
                let headerName = headerData.1
                sizeOfChildren += size
                
                //if Int(currentRootContainer.offset) + currentRootContainer.size < Int(currentOffset) + size { isfinished = true }
                if (sizeOfChildren) == (currentRootContainer.size - 8)  { isfinished = true }
                //print("head size\(size)")
                print(headerName)
                print( "\(sizeOfChildren) and size\(currentRootContainer.size - 8)")
                currentOffset = self.fileReader.currentOffset()
               // print("cur root -> \(currentRootContainer) and offset\(currentRootContainer.offset), cur head-> \(headerData.1)")
                
                    count += 1
                    self.fileReader.read(length: size - self.headerSize) { (data) in
                        do {
                                let typeOfContainer = try self.containerPool.pullOutContainer(with: headerName)
                                var box = self.containerPool.pullOutFileTypeContainer(with: typeOfContainer)
                                box.size = size
                            
                                if box.isParent {
                                   // print("type is \(box.type)")
                                    guard var castedBox = box as? HalfContainer else { return }
                                    castedBox.offset = currentOffset//self.fileReader.currentOffset() - UInt64(size + self.headerSize)
                                    containers.append(castedBox)
                                } else {
                                    box.data = data[0..<(size - self.headerSize)]
                                }
                                currentRootContainer.children.append(box)
                            
                        } catch {
                            assertionFailure("initialization box failed")
                            return
                        }
                    }
               
            }
        }  while !isfinished
        return containers
    }


    
    func makeTracks() {/*
        //var trak = root.moov.traks[0]
        for trak in root.moov.traks {
            let chunks = getSamplePerChunk(track: trak)
            let trackitems = getDurationFromSample(track: trak)
           // let numberOfChunks = trak.mdia.minf.stbl.stco.entryCount
            for (index,offset) in trak.mdia.minf.stbl.stco.chunkOffsets.enumerated() {
                chunks[index].offset = offset
            }
            let numberOfSampleInTrack = trak.mdia.minf.stbl.stsz.sampleCount
            
            let sampleSize = trak.mdia.minf.stbl.stsz.samplesSize
            for index in 0..<numberOfSampleInTrack {
                if sampleSize == 0 {
                    trackitems[index].size = trak.mdia.minf.stbl.stsz.entrySizes[index]
                } else {
                    trackitems[index].size = sampleSize
                }
            }
            
          
        }*/
        
        for trak in root.moov.traks {
        print("trak byte\(trak.data.count)")
        let entryCountForOffset = trak.mdia.minf.stbl.stco.entryCount
        // print(entryCountForOffset)
        let chunks: [Chunk] = [Chunk].init(repeating: Chunk(), count: entryCountForOffset)
        trak.chunks = chunks
        for (index,offset) in trak.mdia.minf.stbl.stco.chunkOffsets.enumerated() {
            trak.chunks[index].offset = (offset)
            //print(trak.chunks)
        }
        
        var sampleNumber = 1
        var nextChunkId = 1
        
        let entryCountForChunk = trak.mdia.minf.stbl.stsc.entryCount
        for i in 0..<entryCountForChunk {
            
            if i + 1 < entryCountForChunk {
                nextChunkId = trak.mdia.minf.stbl.stsc.firstChunks[i+1]
            } else {
                nextChunkId = trak.chunks.count
            }
            
            let firstChunkId = trak.mdia.minf.stbl.stsc.firstChunks[i]
            let samples = trak.mdia.minf.stbl.stsc.samplesPerChunks[i]
            //  print("chunksPer\(samples)")
            let sampleDescriptionIndex = trak.mdia.minf.stbl.stsc.sampleDescriptionIndexies[i]
            var count = firstChunkId - 1
            while count < nextChunkId {
                trak.chunks[count].sampleCount = samples
                // print("now \(samples)")
                trak.chunks[count].sampleDescriptionIndex = sampleDescriptionIndex
                trak.chunks[count].startSample = sampleNumber
                sampleNumber += samples
                
                count += 1
            }
        }
        
        let sampleCount = trak.mdia.minf.stbl.stsz.sampleCount
        trak.samples = [Sample].init(repeating: Sample(), count: sampleCount)
        let sampleSize = trak.mdia.minf.stbl.stsz.samplesSize
        for i in 0..<sampleCount {
            if sampleSize == 0 {
                trak.samples[i].size = trak.mdia.minf.stbl.stsz.entrySizes[i]
            } else {
                trak.samples[i].size = sampleSize
            }
        }
        
        var sampleId = 0
        
        for i in 0..<entryCountForOffset {
            //    print("how? \(trak.samples.count)")
            //
            var sampleOffset = trak.chunks[i].offset
            let count = trak.chunks[i].sampleCount
            // print("i is.. \(i) sam cont \(count)")
            //  print(count)
            for _ in 0..<count {
                //   print("id is \(sampleId)")
                sampleOffset += trak.samples[sampleId].offset
                sampleId += 1
            }
        }
        
        sampleId = 0
        var sampleTime = 0
        for i in 0..<trak.mdia.minf.stbl.stts.entryCount {
            let sampleDuration = trak.mdia.minf.stbl.stts.sampleDeltas[i]
            for _ in 0..<trak.mdia.minf.stbl.stts.sampleCounts[i] {
                trak.samples[sampleId].startTime = sampleTime
                trak.samples[sampleId].duration = sampleDuration
                sampleTime += sampleDuration
                sampleId += 1
            }
        }
        
        if trak.mdia.minf.stbl.ctts.data.count > 0 {
            sampleId = 0
            for i in 0..<trak.mdia.minf.stbl.ctts.entryCount {
                let count = trak.mdia.minf.stbl.ctts.sampleCounts[i]
                let offset = trak.mdia.minf.stbl.ctts.sampleOffsets[i]
                for _ in 0..<count {
                    trak.samples[sampleId].cto = offset
                    sampleId += 1
                }
            }
        }
            
    }
    // }
        root.moov.traks[0].samples.forEach {
            print("\($0.startTime), \($0.size), \($0.offset), \($0.cto)")
        }
   }
    
    private func getDurationFromSample(track: Trak) -> [TrackItem] {
        let numberOfData = track.mdia.minf.stbl.stts.entryCount
        var tracks: [TrackItem] = []
        //var sampleId = 0
        var sampleTime = 0
        for index in 0..<numberOfData {
            let sampleDuration = track.mdia.minf.stbl.stts.sampleDeltas[index]
            for _ in 0..<track.mdia.minf.stbl.stts.sampleCounts[index] {
                let trackItem = TrackItem()
                trackItem.sampleDuration = sampleDuration
                trackItem.startTime = sampleTime
                /*trak.samples[sampleId].startTime = sampleTime
                trak.samples[sampleId].duration = sampleDuration*/
                sampleTime += sampleDuration
                //sampleId += 1
                tracks.append(trackItem)
            }
        }
        return tracks
    }
    
    private func getSamplePerChunk(track: Trak) -> [Chunk] {
        let entryCountForChunk = track.mdia.minf.stbl.stsc.entryCount
        
        var sampleNumber = 1
        var nextChunkId = 1
        var chunks: [Chunk] = []
        
        for index in 0..<entryCountForChunk {
            
            if index + 1 < entryCountForChunk {
                nextChunkId = track.mdia.minf.stbl.stsc.firstChunks[index + 1]
            } else {
                nextChunkId = track.chunks.count
            }
            
            let firstChunkId = track.mdia.minf.stbl.stsc.firstChunks[index]
            let samplePerChunk = track.mdia.minf.stbl.stsc.samplesPerChunks[index]
            let sampleDescriptionIndex = track.mdia.minf.stbl.stsc.sampleDescriptionIndexies[index]
            var count = firstChunkId - 1
            while count < nextChunkId {
                let chunk = Chunk()
                chunk.sampleCount = samplePerChunk
                chunk.sampleDescriptionIndex = sampleDescriptionIndex
                chunk.startSample = sampleNumber
                
                chunks.append(chunk)
                sampleNumber += samplePerChunk
                
                count += 1
            }
        }
        return chunks
    }
    
    func chunkToStream() {
        //print(root.moov.traks[0].chunks)
        let chunks = root.moov.traks[0].chunks
        let samples = root.moov.traks[0].samples
        print(chunks[0].offset)
        print(samples[0].offset)
        print(root.moov.mvhd.creationDate)
    }
}
enum FileContainerType {
    case mp4
}


class TrackItem {
    var sampleDuration: Int = 0
    var startTime: Int = 0
    var size: Int = 0
}

class Track {
    var chunks: [Chunk] = []
}
