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
        return (size, decodedHeaderName)
    }
    
    func decodeFile(type: FileContainerType) {
        //TODO filetype 에 따라 다른 디코딩 방식제공해야함
        var containers: [HalfContainer] = []
        containers = decode(root: self.root)
        while let item = containers.first {
            containers.remove(at: 0)
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
       repeat {
            readHeader() { [weak self] (headerData) in
                guard let self = self else { return }
                let size = headerData.0
                let headerName = headerData.1
                sizeOfChildren += size
                if (sizeOfChildren) == (currentRootContainer.size - 8)  { isfinished = true }
                currentOffset = self.fileReader.currentOffset()
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


    
    func makeTracks() -> [Track] {
        let numberOftracks = root.moov.traks.count
        let tracks: [Track] = [Track](repeating: Track(), count: numberOftracks)
        
        for (index, trak) in root.moov.traks.enumerated() {
            let trackItem = tracks[index]
            
            let numberOfChunks = trak.mdia.minf.stbl.stco.entryCount
            var chunks: [Chunk] = [Chunk](repeating: Chunk(), count: numberOfChunks)
            
            let numberOfsamples = trak.mdia.minf.stbl.stsz.sampleCount
            var samples: [Sample] = [Sample](repeating: Sample(), count: numberOfsamples)
            let sampleSize = trak.mdia.minf.stbl.stsz.samplesSize
            
            for (index,sampleOffset) in trak.mdia.minf.stbl.stco.chunkOffsets.enumerated() {
                chunks[index].offset = sampleOffset
                
            }
            
            var sampleNumber = 1
            let numberOfchunkIndexes = trak.mdia.minf.stbl.stsc.entryCount
            for index in 0..<numberOfchunkIndexes {
                
                let lastIndex = numberOfchunkIndexes - 1
                let firstChunkId = trak.mdia.minf.stbl.stsc.firstChunks[index]
                let samples = trak.mdia.minf.stbl.stsc.samplesPerChunks[index]
                
                let nextChunkId = index != lastIndex ?
                    trak.mdia.minf.stbl.stsc.firstChunks[index+1] : chunks.count
            
                let sampleDescriptionIndex = trak.mdia.minf.stbl.stsc.sampleDescriptionIndexes[index]
                
                var startChunkId = firstChunkId - 1
                while startChunkId < nextChunkId {
                    
                    chunks[startChunkId].sampleCount = samples
                    chunks[startChunkId].sampleDescriptionIndex = sampleDescriptionIndex
                    chunks[startChunkId].startSample = sampleNumber
                    
                    sampleNumber += samples
                    startChunkId += 1
                }
            }
            
            for index in 0..<numberOfsamples {
                 samples[index].size = sampleSize == 0 ?
                    trak.mdia.minf.stbl.stsz.entrySizes[index] : sampleSize
            }
            
            var sampleId = 0
            
            for index in 0..<numberOfChunks {
                var chunkOffset = chunks[index].offset
                let samplesPerChunk = chunks[index].sampleCount
                for _ in 0..<samplesPerChunk {
                    samples[sampleId].offset = chunkOffset
                    chunkOffset += samples[sampleId].size
                    sampleId += 1
                }
            }
            
            sampleId = 0
            
            var sampleTime = 0
            for index in 0..<trak.mdia.minf.stbl.stts.entryCount {
                let sampleDuration = trak.mdia.minf.stbl.stts.sampleDeltas[index]
                for _ in 0..<trak.mdia.minf.stbl.stts.sampleCounts[index] {
                    samples[sampleId].startTime = sampleTime
                    samples[sampleId].duration = sampleDuration
                    sampleTime += sampleDuration
                    sampleId += 1
                }
            }
            
            if !trak.mdia.minf.stbl.ctts.data.isEmpty {
                sampleId = 0
                for index in 0..<trak.mdia.minf.stbl.ctts.entryCount {
                    let numberOfSamples = trak.mdia.minf.stbl.ctts.sampleCounts[index]
                    let sampleOffset = trak.mdia.minf.stbl.ctts.sampleOffsets[index]
                    for _ in 0..<numberOfSamples {
                        samples[sampleId].compositionTimeOffset = sampleOffset
                        sampleId += 1
                    }
                }
            }
            trackItem.chunks = chunks
            trackItem.samples = samples
        }
        return tracks
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
    var samples: [Sample] = []
}
