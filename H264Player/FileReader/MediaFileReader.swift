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
        root.size = 100000000
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
        
        while let item = containers.first {
            containers.remove(at: 0)
            let parentContainers = decode(root: item)
            containers.append(contentsOf: parentContainers)
        }
        root.parse()
        print(root.moov.traks[0])
    }
    
    private func decode(root: HalfContainer) -> [HalfContainer] {
        var containers: [HalfContainer] = []
        var currentRootContainer: HalfContainer = root
        var currentOffset = currentRootContainer.offset
        fileReader.seek(offset: currentOffset)
        while fileReader.hasAvailableData() {
            readHeader() { [weak self] (headerData) in
                guard let self = self else { return }
                let size = headerData.0
                let headerName = headerData.1
                currentOffset = self.fileReader.currentOffset()
                
                self.fileReader.read(length: size - self.headerSize) { (data) in
                    do {
                        if Int(currentRootContainer.offset) + currentRootContainer.size > Int(currentOffset) {
                            let typeOfContainer = try self.containerPool.pullOutContainer(with: headerName)
                            var box = self.containerPool.pullOutFileTypeContainer(with: typeOfContainer)
                            box.size = size
                            if box.isParent {
                                guard var castedBox = box as? HalfContainer else { return }
                                castedBox.offset = currentOffset
                                containers.append(castedBox)
                            } else {
                                box.data = data[0..<(size - self.headerSize)]
                            }
                            currentRootContainer.children.append(box)
                        }
                        
                    } catch {
                        assertionFailure("initialization box failed")
                        return
                    }
                }
            }
            if Int(currentRootContainer.offset) + currentRootContainer.size < Int(currentOffset) { break }
        }
        return containers
    }

    
    
    func makeTracks() {
        var trak = root.moov.traks[0]
        //for trak in root.moov.traks {
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
                for _ in 0..<count-1 {
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


