//
//  MediaFileReader.swift
//  MPEG-4Parser
//
//  Created by bumslap on 29/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

class Mpeg4Parser: MediaFileReadable {
    
    private(set) var status: MediaStatus = .paused
    private(set) var fileReader: FileStreamReadable
    private(set) var root = RootType()
    
    private let containerPool: ContainerPool = ContainerPool()
    private let headerSize = 8
    private let lockQueue: DispatchQueue = DispatchQueue(label: "mediaFileReadQueue")
    
    init(fileReader: FileStreamReadable) {
        self.fileReader = fileReader
    }
    
    private func extractTypeHeader(completion: @escaping ((Int, String))->()) {
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
    
    func decodeMediaData() {
        status = .paused
        var containers: [HalfContainer] = []
        root.size = Int(fileReader.fileHandler.seekToEndOfFile()) + headerSize
        
        lockQueue.sync { [weak self] in
            guard let self = self else { return }
            self.status = .paused
            containers = decode(root: root)
            
            while let item = containers.first {
                containers.remove(at: 0)
                let parentContainers = decode(root: item)
                containers.append(contentsOf: parentContainers)
            }
        }
        
       lockQueue.sync { [weak self] in
        guard let self = self else { return }
            self.root.parse()
        self.status = .prepared
        }
    }
    
    private func decode(root: HalfContainer) -> [HalfContainer] {
        var containers: [HalfContainer] = []
        var currentRootContainer: HalfContainer = root
        var currentOffset = currentRootContainer.offset
        var isfinished: Bool = false
        fileReader.seek(offset: currentOffset)
        var sizeOfChildren = 0
        
       repeat {
            extractTypeHeader() { [weak self] (headerData) in
                guard let self = self else { return }
                
                let size = headerData.0
                let headerName = headerData.1
                
                sizeOfChildren += size
                if (sizeOfChildren) == (currentRootContainer.size - 8)  {
                    isfinished = true
                }
                currentOffset = self.fileReader.currentOffset()
                    self.fileReader.read(length: size - self.headerSize) { (data) in
                        do {
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
        var tracks: [Track] = []
        
        for trak in root.moov.traks {
            let trackItem = Track(type: .unknown)
            
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
            
            
            trackItem.duration = trak.tkhd.duration
            trackItem.timescale = trak.mdia.mdhd.timeScale
            
            if trak.mdia.hdlr.handlerType == "vide" {
                let avcC = trak.mdia.minf.stbl.stsd.avc1.avcc
                trackItem.mediaType = .video
                trackItem.sequenceParameters = avcC.sequenceParameters
                trackItem.sequenceParameterSet = avcC.sequenceParameterSet
                trackItem.pictureParameters = avcC.pictureParams
                trackItem.pictureParameterSet = avcC.pictureParameterSet
            } else {
                let mp4a = trak.mdia.minf.stbl.stsd.mp4a
                trackItem.mediaType = .audio
                trackItem.sampleRate = mp4a.sampleRate
                trackItem.numberOfChannels = mp4a.numberOfChannels
            }
            
            trackItem.chunks = chunks
            trackItem.samples = samples
            tracks.append(trackItem)
        }
        return tracks
    }
}
    

