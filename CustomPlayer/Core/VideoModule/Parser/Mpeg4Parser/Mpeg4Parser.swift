//
//  MediaFileReader.swift
//  MPEG-4Parser
//
//  Created by bumslap on 29/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

class Mpeg4Parser {
    
    private(set) var status: MediaStatus = .paused
    private(set) var fileReader: FileStreamReadable
    private(set) var root = RootType()
    
    private var sequenceParameterSet: Data = Data()
    private var sequenceParameters: [Data] = []
    
    private var pictureParameterSet: Data = Data()
    private var pictureParameters: [Data] = []
    
    private var sampleSizeArray: [Int] = []
    private var duration: Double = 0
    
    private let containerPool: ContainerPool = ContainerPool()
    private let headerSize = 8
    private let jobQueue: DispatchQueue = DispatchQueue(label: "mp4JobQueue")
    
    
    
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
    
    func parse(completion: @escaping (Result<[DataStream], Error>) -> Void) {
        status = .paused
        jobQueue.async { 
            
            var containers: [HalfContainer] = []
            self.root.size = Int(self.fileReader.fileHandler.seekToEndOfFile()) + self.headerSize
            
            
            self.status = .paused
            containers = self.doParse(root: self.root)
            
            while let item = containers.first {
                containers.remove(at: 0)
                let parentContainers = self.doParse(root: item)
                containers.append(contentsOf: parentContainers)
            }
        
            self.root.parse()
            let tracks = self.makeTracks()
            let streams = self.processTracks(tracks: tracks)
            self.status = .prepared
            self.cleanUp()
            completion(.success(streams))
        }
       
    }
    
    private func doParse(root: HalfContainer) -> [HalfContainer] {
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

    
   private func makeTracks() -> [Track] {
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
    
    private func processTracks(tracks: [Track]) -> [DataStream] {
        var streams: [DataStream] = []
        for track in tracks {
            var packet: [Data] = []
            var presentationTimestamp: [Int] = []
            
            for sample in track.samples {
                
                fileReader.seek(offset: UInt64(sample.offset))
                fileReader.read(length: sample.size) { (data) in
                    packet.append(data)
                }
            }
            presentationTimestamp = track.samples.map {
                $0.startTime + $0.compositionTimeOffset
            }
            
            switch track.mediaType {
            case .video:
                sampleSizeArray = track.samples.map {
                    $0.size
                }
                let videoStream = DataStream()
                videoStream.actualData = Array(packet.joined())
                videoStream.type = .video
                videoStream.pts = presentationTimestamp
                videoStream.dts = presentationTimestamp
                
                sequenceParameterSet = track.sequenceParameterSet
                sequenceParameters = track.sequenceParameters
                
                pictureParameterSet = track.pictureParameterSet
                pictureParameters = track.pictureParameters
                
                duration = Double(track.duration)
                
                streams.append(videoStream)

            case .audio:
                let audioStream = DataStream()
                audioStream.actualData = Array(packet.map {
                    $0.addADTS
                }.joined())
                
                audioStream.type = .audio
                audioStream.pts = presentationTimestamp
                audioStream.dts = presentationTimestamp
                streams.append(audioStream)
            default:
                assertionFailure("failed to make Stream")
            }
        }
        return streams
    }
    
    func fetchMetaData() -> MP4MetaData {
        let metaData = MP4MetaData(totalDuration: duration, sampleSizeArray: sampleSizeArray, sequenceParameterSet: sequenceParameterSet, sequenceParameters: sequenceParameters, pictureParameterSet: pictureParameterSet, pictureParameters: pictureParameters)
        return metaData
    }
    
    private func cleanUp() {
        fileReader.close()

    }
}
    

