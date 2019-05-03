//
//  Models.swift
//  MPEG-4Parser
//
//  Created by USER on 26/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation


enum ContainerType: String, CaseIterable {
    case root
    case ftyp
    case free
    case mdat
    case moov
    case iods
    case mvhd
    case trak
    case tkhd
    case edts
    case elst
    case mdia
    case mdhd
    case hdlr
    case minf
    case vmhd
    case smhd
    case dinf
    case dref
    case stbl
    case co64
    case ctts
    case stsd
    case sbgp
    case sgpd
    case sdtp
    case avc1
    case avcc
    case mp4a
    case esds
    case stts
    case stss
    case stsc
    case stsz
    case stco
    case udta
    case meta
}



class RootType: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .root
    var size: Int = 0
    var data: Data = Data()
    
    var ftyp: Ftyp = Ftyp()
    var free: Free = Free()
    var moov: Moov = Moov()
    var udta: Udta = Udta()
    var mdat: Mdat = Mdat()
    
    var children: [Container] = []

    func parse() {
        children.forEach {
            switch $0.type {
            case .ftyp:
                $0.parse()
                self.ftyp = $0 as! Ftyp
            case .free:
                $0.parse()
                self.free = $0 as! Free
            case .moov:
                $0.parse()
                self.moov = $0 as! Moov
            case .mdat:
                $0.parse()
                self.mdat = $0 as! Mdat
            default:
                assertionFailure("failed to make root")
            }
        }
    }
}

class Ftyp: Container {
    
    var type: ContainerType = .ftyp
    var size: Int = 0
    var data: Data = Data()
    
    var majorBrand: String = ""
    var minorVersion: String = ""
    var compatibleBrand: [String] = []
    
    func parse() {
        let dataArray = data.slice(in: [4,4,4,4])
        majorBrand = dataArray[0].convertToString
        minorVersion = dataArray[1].convertToString
        compatibleBrand = [dataArray[2].convertToString]
                           //dataArray[3].convertToString]
    }
}

class Free: Container {
    
    var type: ContainerType = .free
    var size: Int = 0
    var data: Data = Data()
    
    func parse() {}
}

class Mdat: Container {
    
    var type: ContainerType = .mdat
    var size: Int = 0
    var data: Data = Data()
    func parse() {}
}

class Moov: HalfContainer {
    var offset: UInt64 = 0
    var type: ContainerType = .moov
    var size: Int = 0
    var data: Data = Data()
    
    var udta: Udta = Udta()
    var mvhd: Mvhd = Mvhd()
    var iods: Iods = Iods()
    var traks: [Trak] = []
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            switch $0.type {
            case .mvhd:
                $0.parse()
                self.mvhd = $0 as! Mvhd
            case .iods:
                $0.parse()
                self.iods = $0 as! Iods
            case .udta:
                $0.parse()
                self.udta = $0 as! Udta
            case .trak:
                $0.parse()
                self.traks.append($0 as! Trak)
            default:
                assertionFailure("failed to make moov")
            }
        }
    }
}

class Mvhd: Container {
   
    var type: ContainerType = .mvhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flag: Int = 0
    var creationDate: Date = Date()
    var modificationTime: Date = Date()
    var timeScale: Int = 0
    var duration: Int = 0
    var nextTrackId: Int = 0
    var rate: Int = 0
    var volume: Int = 0
    var others: Int = 0

    func parse() {
        let dataArray = data.slice(in: [1,3,4,4,4,4,4,2])
        version = dataArray[0].convertToInt
        flag = dataArray[1].convertToInt
        creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
        timeScale = dataArray[4].convertToInt
        duration = dataArray[5].convertToInt
        nextTrackId = dataArray[6].convertToInt
        rate = dataArray[7].convertToInt
    }
}

class Iods: Container {
    
    var type: ContainerType = .iods
    var size: Int = 0
    var data: Data = Data()
    
    func parse() {}
}

class Trak: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .trak
    var size: Int = 0
    var data: Data = Data()
    
    var tkhd: Tkhd = Tkhd()
    var mdia: Mdia = Mdia()
    var edts: Edts = Edts()
    var chunks: [Chunk] = []
    var samples: [Sample] = []
    
    var children: [Container] = []

    func parse() {
        children.forEach {
            switch $0.type {
            case .tkhd:
                $0.parse()
                self.tkhd = $0 as! Tkhd
            case .mdia:
                $0.parse()
                self.mdia = $0 as! Mdia
            case .edts:
                $0.parse()
                self.edts = $0 as! Edts
            default:
                assertionFailure("failed to make trak")
            }
        }
    }
}

class Tkhd: Container {
    
    var type: ContainerType = .tkhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flag: Int = 0
    var creationDate: Date = Date()
    var modificationTime: Date = Date()
    var layer: Int = 0
    var alternateGroup: Int = 0
    var duration: Int = 0
    var trackId: Int = 0
    var volume: Int = 0
    var matrix: [Int] = []
    var width: Int = 0
    var height: Int = 0
    
    init() {}
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4,4,4,4,8,2,2,2,2,36,4,4])
        version = dataArray[0].convertToInt
        flag = dataArray[1].convertToInt
        creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[2].convertToInt))
        modificationTime = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
        trackId = dataArray[4].convertToInt
            //reserve 4
        duration = dataArray[6].convertToInt
            //reserve 8
        layer = dataArray[8].convertToInt
        
        alternateGroup = dataArray[9].convertToInt
        volume = dataArray[10].convertToInt
        matrix = []
        width = dataArray[12].convertToInt
        height = dataArray[13].convertToInt
    }
}

class Edts: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .edts
    var size: Int = 0
    var data: Data = Data()
    
    var elst: Elst = Elst()
    
    init() {}
    
    var children: [Container] = []
    func parse() {
        children.forEach {
            if $0.type == .elst {
                $0.parse()
                self.elst = $0 as! Elst
            }
        }
    }
}
    
class Elst: Container {
    
    var type: ContainerType = .elst
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var segmentDuration: [Int] = []
    var mediaTime: [Int] = []
    var mediaRateInteger: [Int] = []
    var mediaRateFraction: [Int] = []

    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let seg = data.subdata(in: (8 + 12 * i)..<(12 + 12 * i)).convertToInt
            let mt = data.subdata(in: (12 + 12 * i)..<(16 + 12 * i)).convertToInt
            let mri = data.subdata(in: (16 + 12 * i)..<(18 + 12 * i)).convertToInt
            let mrf = data.subdata(in: (18 + 12 * i)..<(20 + 12 * i)).convertToInt
            segmentDuration.append(seg)
            mediaTime.append(mt)
            mediaRateInteger.append(mri)
            mediaRateFraction.append(mrf)
        }
    }
}

class Mdia: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .mdia
    var size: Int = 0
    var data: Data = Data()
    
    var mdhd: Mdhd = Mdhd()
    var hdlr: Hdlr = Hdlr()
    var minf: Minf = Minf()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            switch $0.type {
            case .mdhd:
                $0.parse()
                self.mdhd = $0 as! Mdhd
            case .hdlr:
                $0.parse()
                self.hdlr = $0 as! Hdlr
            case .minf:
                $0.parse()
                self.minf = $0 as! Minf
            default:
                assertionFailure("failed to make mdia")
            }
        }
    }
}

class Mdhd: Container {
    
    var type: ContainerType = .mdhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flag: Int = 0
    var creationDate: Date = Date()
    var modificationTime: Date = Date()
    var timeScale: Int = 0
    var duration: Int = 0
    var language: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4,4,4,2])
        version = dataArray[0].convertToInt
        flag = dataArray[1].convertToInt
        creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[2].convertToInt))
        modificationTime = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
        timeScale = dataArray[4].convertToInt
        duration = dataArray[5].convertToInt
        language = dataArray[6].convertToInt
    }
}
    
class Hdlr: Container {
    
    var type: ContainerType = .hdlr
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var preDefined: Int = 0
    var handlerType: String = ""
    var trackName: String = ""
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        preDefined = dataArray[2].convertToInt
        handlerType = dataArray[3].convertToString
        trackName = data.subdata(in: 24..<data.count).convertToString
    }
}
    
class Minf: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .minf
    var size: Int = 0
    var data: Data = Data()
    
    var vmhd: Vmhd = Vmhd()
    var smhd: Smhd = Smhd()
    var stbl: Stbl = Stbl()
    var dinf: Dinf = Dinf()
    var hdlr: Hdlr = Hdlr()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            switch $0.type {
            case .vmhd:
                $0.parse()
                self.vmhd = $0 as! Vmhd
            case .smhd:
                $0.parse()
                self.smhd = $0 as! Smhd
            case .stbl:
                $0.parse()
                self.stbl = $0 as! Stbl
            case .dinf:
                $0.parse()
                self.dinf = $0 as! Dinf
            case .hdlr:
                $0.parse()
                self.hdlr = $0 as! Hdlr
            default:
                assertionFailure("failed to make mdia")
            }
        }
    }
}

class Vmhd: Container {
    
    var type: ContainerType = .vmhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var graphicsmode: Int = 0
    var opcolor: [Int] = [] //[3]
    
    func parse() {
        let dataArray = data.slice(in: [1,3,2,2])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        graphicsmode = dataArray[2].convertToInt
        for i in 0..<3 {
            self.opcolor.append(data.subdata(in: (6 + 2 * i)..<(8 + 2 * i)).convertToInt)
        }
    }
}

class Smhd: Container {
    
    var type: ContainerType = .smhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var balance: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,2])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.balance = dataArray[2].convertToInt
    }
}

class Dinf: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .dinf
    var size: Int = 0
    var data: Data = Data()
    
    var dref: Dref = Dref()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            if $0.type == .dref {
                $0.parse()
                self.dref = $0 as! Dref
            }
        }
    }
}

class Dref: Container {
    
    var type: ContainerType = .dref
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var others: Int = 0
    
    init() {}
    
    func parse() {
        let dataArray = data.slice(in: [1,3,2])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
    }
}
    
class Stbl: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .stbl
    var size: Int = 0
    var data: Data = Data()
    
    var stsd: Stsd = Stsd()// mandatory
    var stts: Stts = Stts() // mandatory
    var stss: Stss = Stss()
    var stsc: Stsc = Stsc()// mandatory
    var stsz: Stsz = Stsz()// mandatory
    var stco: Stco = Stco()// mandatory
    var co64: Co64 = Co64() // mandatory 4기가 이상의 파일일 경우
    var ctts: Ctts = Ctts()
    var sdtp: Sdtp = Sdtp()
    var sgpd: Sgpd = Sgpd()
    var sbgp: Sbgp = Sbgp()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            switch $0.type {
            case .stsd:
                $0.parse()
                self.stsd = $0 as! Stsd
            case .stts:
                $0.parse()
                self.stts = $0 as! Stts
            case .stss:
                $0.parse()
                self.stss = $0 as! Stss
            case .stsc:
                $0.parse()
                self.stsc = $0 as! Stsc
            case .stsz:
                $0.parse()
                self.stsz = $0 as! Stsz
            case .stco:
                $0.parse()
                self.stco = $0 as! Stco
            case .co64:
                $0.parse()
                self.co64 = $0 as! Co64
            case .ctts:
                $0.parse()
                self.ctts = $0 as! Ctts
            case .sdtp:
                $0.parse()
                self.sdtp = $0 as! Sdtp
            case .sgpd:
                $0.parse()
                self.sgpd = $0 as! Sgpd
            case .sbgp:
                $0.parse()
                self.sbgp = $0 as! Sbgp
            default:
                assertionFailure("failed to make stbl with\($0.type)")
            }
        }
    }
}

class Co64: Container {
    
    var type: ContainerType = .co64
    var size: Int = 0
    var data: Data = Data()
    
    func parse() {}
}

class Ctts: Container {
    
    var type: ContainerType = .ctts
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var sampleCounts: [Int] = []
    var sampleOffsets: [Int] = []
    
    func parse(){
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt

        for i in 0..<entryCount {
            let sampleCount = data.subdata(in: (8 + 8 * i)..<(12 + 8 * i)).convertToInt
            let sampleOffset = data.subdata(in: (12 + 8 * i)..<(16 + 8 * i)).convertToInt
            sampleCounts.append(sampleCount)
            sampleOffsets.append(sampleOffset)
        }
    }
}

class Stsd: Container {
    
    var offset: UInt64 = 0
    var type: ContainerType = .stsd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var avc1 = Avc1()
    var mp4a = Mp4a()

    func parse() {
        let containerPool = ContainerPool()
        let extractedData = data[data.startIndex + 12..<data.startIndex + 16].convertToString
        let typeOfChildren = try? containerPool.pullOutContainer(with: extractedData)
        
            switch typeOfChildren! {
            case .mp4a:
                mp4a.data = data[(data.startIndex + 8)...]
                mp4a.parse()
            case .avc1:
                avc1.data = data[(data.startIndex + 8)...]
                avc1.parse()
            default:
                assertionFailure("no type")
            }
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
    }
}

class Avc1: Container {
    var type: ContainerType = .avc1
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    
    var referenceIndex = 0
    var width = 0
    var height = 0
    var compressor = ""
    
    var avcc = Avcc()

    func parse() {
        avcc.data = self.data[(data.startIndex + 94)...]
        avcc.parse()
    }
}

class Avcc: Container {
    
    var type: ContainerType = .avcc
    var size: Int = 0
    var data: Data = Data()
    
    var version = 0
    var profile = ""
    var compat = 0
    var level = 0
    var naluLength = 0
    
    var sequenceParameterSet: Data = Data()
    var sequenceParameterEntry = 0
    var sequenceParameters: [Data] = []
    
    var pictureParameterSet: Data = Data()
    var pictureParameterEntry  = 0
    var pictureParams: [Data] = []

    func parse() {
        let startIndex = data.startIndex
        sequenceParameterSet = data.subdata(in: startIndex + 6..<startIndex + 7)
        
        sequenceParameterEntry = data.subdata(in: startIndex + 6..<startIndex + 8).convertToInt
        for i in 0..<sequenceParameterEntry {
            sequenceParameters.append(data.subdata(in: (startIndex + 8 + i)..<(startIndex + 9 + i)))
        }
        
        let pictureParamterOffset = startIndex + sequenceParameterEntry + 8
        pictureParameterSet = data.subdata(in: pictureParamterOffset..<pictureParamterOffset+1)
        pictureParameterEntry = data.subdata(in: (pictureParamterOffset + 1)..<(pictureParamterOffset + 3)).convertToInt
        
        for i in 0..<pictureParameterEntry {
            pictureParams.append(data.subdata(in: (pictureParamterOffset + 3 + i)..<((pictureParamterOffset + 4 + i))))
        }
    }
}

class Esds: Container {
    var type: ContainerType = .esds
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    
    var esDescriptor = EsDescriptor()
    
    func parse() {
    }
}

//TODO: 구현예정
class EsDescriptor: Container {
    var type: ContainerType = .stts
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var sampleCounts: [Int] = []
    var sampleDeltas: [Int] = []
    
    func parse() {}
}

class Mp4a: Container {
    var type: ContainerType = .mp4a
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    
    //reserved 6byte
    var dataReferenceIndex = 0
    var version = 0
    var revisionLevel = 0
    var vendor = 0
    var numberOfChannels = 0
    var sampleSize = 0
    var compressionId = 0
    //reserved 2 byte
    var sampleRate = 0
    
    var esds = Esds()

    func parse() {
        let startIndex = data.startIndex
        dataReferenceIndex = data.subdata(in: startIndex + 14..<startIndex + 16).convertToInt
        version = data.subdata(in: startIndex + 16..<startIndex + 18).convertToInt
        revisionLevel = data.subdata(in: startIndex + 18..<startIndex + 20).convertToInt
        vendor = data.subdata(in: startIndex + 20..<startIndex + 24).convertToInt
        numberOfChannels = data.subdata(in: startIndex + 24..<startIndex + 26).convertToInt
        sampleSize = data.subdata(in: startIndex + 26..<startIndex + 28).convertToInt
        compressionId = data.subdata(in: startIndex + 28..<startIndex + 30).convertToInt
        sampleRate = data.subdata(in: startIndex + 30..<startIndex + 34).convertToInt
        esds.data = self.data[(data.startIndex + 34)...]
        esds.parse()
    }
}

class Stts: Container {
    
    var type: ContainerType = .stts
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var sampleCounts: [Int] = []
    var sampleDeltas: [Int] = []
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let sampleCount = data.subdata(in: (8 + 8 * i)..<(12 + 8 * i)).convertToInt
            let sampleDelta = data.subdata(in: (12 + 8 * i)..<(16 + 8 * i)).convertToInt
            sampleCounts.append(sampleCount)
            sampleDeltas.append(sampleDelta)
        }
    }
}
    
class Stss: Container {
    
    var type: ContainerType = .stss
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var sampleNumbers: [Int] = []
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let sample = data.subdata(in: (8 + 4 * i)..<(12 + 4 * i)).convertToInt
            sampleNumbers.append(sample)
        }
    }
}
    
class Stsc: Container {
    
    var type: ContainerType = .stsc
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var firstChunks: [Int] = []
    var samplesPerChunks: [Int] = []
    var sampleDescriptionIndexes: [Int] = []
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let firstChunk = data.subdata(in: (8 + 12 * i)..<(12 + 12 * i)).convertToInt
            let samplesPerChunk = data.subdata(in: (12 + 12 * i)..<(16 + 12 * i)).convertToInt
            let sampleDescriptionIndex = data.subdata(in: (16 + 12 * i)..<(20 + 12 * i)).convertToInt
            firstChunks.append(firstChunk)
            samplesPerChunks.append(samplesPerChunk)
            sampleDescriptionIndexes.append(sampleDescriptionIndex)
        }
    }
}

class Stsz: Container {
    
    var type: ContainerType = .stsz
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entrySizes: [Int] = []
    var samplesSize: Int = 0
    var sampleCount: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        samplesSize = dataArray[2].convertToInt
        sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                entrySizes.append(entry)
            }
        }
    }
}

class Sdtp: Container {
    
    var type: ContainerType = .sdtp
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entrySizes: [Int] = []
    var samplesSize: Int = 0
    var sampleCount: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        samplesSize = dataArray[2].convertToInt
        sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                entrySizes.append(entry)
            }
        }
    }
}

class Sgpd: Container {
    
    var type: ContainerType = .sgpd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entrySizes: [Int] = []
    var samplesSize: Int = 0
    var sampleCount: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        samplesSize = dataArray[2].convertToInt
        sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                entrySizes.append(entry)
            }
        }
    }
}

class Sbgp: Container {
    
    var type: ContainerType = .sbgp
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entrySizes: [Int] = []
    var samplesSize: Int = 0
    var sampleCount: Int = 0
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        samplesSize = dataArray[2].convertToInt
        sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                entrySizes.append(entry)
            }
        }
    }
}
    
class Stco: Container {
    
    var type: ContainerType = .stco
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var chunkOffsets: [Int] = []
    
    func parse() {
        let dataArray = data.slice(in: [1,3,4])
        version = dataArray[0].convertToInt
        flags = dataArray[1].convertToInt
        entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let chunkOffset = data.subdata(in: (8 + 4 * i)..<(12 + 4 * i)).convertToInt
            chunkOffsets.append(chunkOffset)
        }
    }
}

class Udta: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .udta
    var size: Int = 0
    var data: Data = Data()
    
    var meta: Meta = Meta()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            if $0.type == .meta {
                $0.parse()
                meta = $0 as! Meta
            }
        }
    }
}


class Meta: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .meta
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flag: Int = 0
    var handler: Hdlr = Hdlr()
    
    var children: [Container] = []
    
    func parse() {
        children.forEach {
            if $0.type == .hdlr {
                $0.parse()
                self.handler = $0 as! Hdlr
            }
        }
    }
}

struct Chunk {
    var sampleDescriptionIndex: Int = 0
    var firstSample: Int = 0
    var sampleCount: Int = 0
    var startSample: Int = 0
    var offset: Int = 0
    
    init() {}
}

struct Sample {
    var size: Int = 0
    var offset: Int = 0
    var startTime: Int = 0
    var duration: Int = 0
    var compositionTimeOffset: Int = 0
    
    init() {}
}
