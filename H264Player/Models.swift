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

extension ContainerType {
    var isParent: Bool {
        if self == .moov || self == .trak || self == .mdia || self == .minf
            || self == .dinf || self == .stbl || self == .edts || self == .stsd || self == .esds
        || self == .mp4a || self == .avc1 || self == .udta || self == .meta{
            return true
        } else {
            return false
        }
    }
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
        print("\(type) is parsing..")
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
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [4,4,4,4])
        majorBrand = dataArray[0].convertToString
        minorVersion = dataArray[1].convertToString
        compatibleBrand = [dataArray[2].convertToString,
                           dataArray[3].convertToString]
        
    }
    
   /* init(majorBrand: String, minorVersion: String, compatibleBrand: [String] ) {
        self.majorBrand = majorBrand
        self.minorVersion = minorVersion
        self.compatibleBrand = compatibleBrand
    }*/
}

class Free: Container {
    
    var type: ContainerType = .free
    var size: Int = 0
    var data: Data = Data()
    
    func parse() {
        print("\(type) is parsing..")
        //TODO: freetype parse
    }
    
    /*init(data: Data) {
        self.data = data
    }*/
}
class Mdat: Container {
    
    var type: ContainerType = .mdat
    var size: Int = 0
    var data: Data = Data()
    func parse() {
        print("\(type) is parsing..")
    }
    /*init(data: Data) {
        self.data = data
    }*/
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
        print("\(type) is parsing..")
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
    /*init(mvhd: Mvhd, iods: Iods) {
        self.mvhd = mvhd
        self.iods = iods
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4,4,4,4,2])
       
       // print(data.count)
        self.version = dataArray[0].convertToInt
        self.flag = dataArray[1].convertToInt
       // print("is//\(dataArray[2].convertToInt)")
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
       // self.creationDate = dataArray[2]
       // self.modificationTime = dataArray[3]
        self.timeScale = dataArray[4].convertToInt
        self.duration = dataArray[5].convertToInt
        self.nextTrackId = dataArray[6].convertToInt
        self.rate = dataArray[7].convertToInt
        //self.volume = dataArray[8]
//        self.others = dataArray
    
    }
    /*init(version: Int,
         flag: Int,
         creationDate: Date,
         modificationTime: Date,
         timeScale: Int,
         duration: Int,
         nextTrackId: Int,
         rate: Int,
         volume: Int,
         others: Int) {
        self.version = version
        self.flag = flag
        self.creationDate = creationDate
        self.modificationTime = modificationTime
        self.timeScale = timeScale
        self.duration = duration
        self.nextTrackId = nextTrackId
        self.rate = rate
        self.volume = volume
        self.others = others
    }*/
}

class Iods: Container {
    
    var type: ContainerType = .iods
    var size: Int = 0
    var data: Data = Data()
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
    }
    /*init(data: Data) {
        self.data = data
    }*/
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
    
    init() {}
    
    func parse() {
       print("\(type) is parsing..")
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
   /* init(tkhd: Tkhd,
         mdia: Mdia,
         chunks: [Chunk],
         samples: [Sample]) {
        self.tkhd = tkhd
        self.mdia = mdia
        self.chunks = chunks
        self.samples = samples
    }*/
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
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4,4,4,4,8,2,2,2,2,36,4,4])
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[2].convertToInt))
        //self.modificationTime = dataArray[3].convertToInt
        self.trackId = dataArray[4].convertToInt
        
        self.version = dataArray[0].convertToInt
        self.flag = dataArray[1].convertToInt
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[2].convertToInt))
        self.modificationTime = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
        self.trackId = dataArray[4].convertToInt
            //reserve 4
        self.duration = dataArray[6].convertToInt
            //reserve 8
        self.layer = dataArray[8].convertToInt
        
        self.alternateGroup = dataArray[9].convertToInt
        self.volume = dataArray[10].convertToInt
        self.matrix = []
        self.width = dataArray[12].convertToInt
        self.height = dataArray[13].convertToInt
        
    }
   /* init(version: Int,
         flag: Int,
         creationDate: Date,
         modificationTime: Date,
         timeScale: Int,
         duration: Int,
         trackId: Int,
         layer: Int,p
         alternateGroup: Int,
         volume: Int,
         matrix: [Int],
         width: Int,
         height: Int) {
        self.version = version
        self.flag = flag
        self.creationDate = creationDate
        self.modificationTime = modificationTime
        self.layer = layer
        self.alternateGroup = alternateGroup
        self.duration = duration
        self.trackId = trackId
        self.volume = volume
        self.matrix = matrix
        self.width = width
        self.height = height
    }*/
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
        print("\(type) is parsing..")
        children.forEach {
            if $0.type == .elst {
                $0.parse()
                self.elst = $0 as! Elst
            }
        }
    }
    /*init(elst: Elst) {
        self.elst = elst
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let seg = data.subdata(in: (8+12*i)..<(12+12*i)).convertToInt
            let mt = data.subdata(in: (12+12*i)..<(16+12*i)).convertToInt
            let mri = data.subdata(in: (16+12*i)..<(18+12*i)).convertToInt
            let mrf = data.subdata(in: (18+12*i)..<(20+12*i)).convertToInt
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
    
    init() {}
    
    
    func parse() {
        print("\(type) is parsing..")
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
    /*init(mdhd: Mdhd, hdlr: Hdlr, minf: Minf) {
        self.mdhd = mdhd
        self.hdlr = hdlr
        self.minf = minf
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4,4,4,2])
        self.version = dataArray[0].convertToInt
        self.flag = dataArray[1].convertToInt
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(dataArray[2].convertToInt))
        self.modificationTime = Date(timeIntervalSince1970: TimeInterval(dataArray[3].convertToInt))
        self.timeScale = dataArray[4].convertToInt
        self.duration = dataArray[5].convertToInt
        self.language = dataArray[6].convertToInt
    }
    
    /*init(version: Int,
         flag: Int,
         creationDate: Date,
         modificationTime: Date,
         timeScale: Int,
         duration: Int,
         language: Int
         ) {
        self.version = version
        self.flag = flag
        self.creationDate = creationDate
        self.modificationTime = modificationTime
        self.timeScale = timeScale
        self.duration = duration
        self.language = language
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.preDefined = dataArray[2].convertToInt
        self.handlerType = dataArray[3].convertToString
        self.trackName = data.subdata(in: 24..<data.count).convertToString
    }
    /*init(version: Int,
         flags: Int,
         preDefined: Int,
         handlerType: String,
         trackName: String) {
        self.version = version
        self.flags = flags
        self.preDefined = preDefined
        self.handlerType = handlerType
        self.trackName = trackName
    }*/
    
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
    
    init() {}
    
    
    func parse() {
        print("\(type) is parsing..")
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
    /*init(vmhd: Vmhd, smhd: Smhd, stbl: Stbl, dinf: Dinf, hdlr: Hdlr) {
        self.vmhd = vmhd
         self.smhd = smhd
         self.stbl = stbl
         self.dinf = dinf
         self.hdlr = hdlr
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,2,2])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.graphicsmode = dataArray[2].convertToInt
        for i in 0..<3 {
            self.opcolor.append(data.subdata(in: (6 + 2 * i)..<(8 + 2 * i)).convertToInt)
        }
    }
    
   /* init(version: Int, flags: Int, graphicsmode: Int, opcolor: Int) {
        self.version = version
        self.flags = flags
        self.graphicsmode = graphicsmode
        self.opcolor = opcolor
    }*/
}
class Smhd: Container {
    
    var type: ContainerType = .smhd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var balance: Int = 0
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,2])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.balance = dataArray[2].convertToInt
    }
    
   /* init(version: Int, flags: Int, balance: Int) {
        self.version = version
        self.flags = flags
        self.balance = balance
    }*/
}

class Dinf: HalfContainer {
    var offset: UInt64 = 0
    
    
    var type: ContainerType = .dinf
    var size: Int = 0
    var data: Data = Data()
    
    var dref: Dref = Dref()
    
    var children: [Container] = []
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            if $0.type == .dref {
                $0.parse()
                self.dref = $0 as! Dref
            }
        }
    }
    
   /* init(dref: Dref) {
        self.dref = dref
    }*/
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
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,2])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
    }
    /*init(version: Int, flags: Int, entryCount: Int) {
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.others = 0
    }*/
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
    
    init() {}
    
    
    func parse() {
        print("\(type) is parsing..")
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
    
    /*init(stsd: Stsd, stts: Stts, stsc: Stsc, stsz: Stsz, stco: Stco) {
        self.stsd = stsd
        self.stts = stts
        self.stsc = stsc
        self.stsz = stsz
        self.stco = stco
    }*/
}
class Co64: Container {
    
    var type: ContainerType = .co64
    var size: Int = 0
    var data: Data = Data()
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
    }
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
    
    init() {}
    
    func parse(){
       print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt

        for i in 0..<entryCount {
            let sampleCount = data.subdata(in: (8 + 8 * i)..<(12 + 8 * i)).convertToInt
            let sampleOffset = data.subdata(in: (12 + 8 * i)..<(16 + 8 * i)).convertToInt
            self.sampleCounts.append(sampleCount)
            self.sampleOffsets.append(sampleOffset)

        }
    }
    
    /*init(version: Int,
         flags: Int,
         entryCount: Int,
         sampleCounts: [Int],
         sampleOffset: [Int]) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.sampleCounts = sampleCounts
        self.sampleOffset = sampleOffset
    }*/
}

class Stsd: HalfContainer {
    
    var offset: UInt64 = 0
    var type: ContainerType = .stsd
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var avc1 = Avc1()
    var mp4a = Mp4a()
    
    var children: [Container] = []
    
    init() {}
    
    func parse() {
        children.forEach {
            switch $0.type {
            case .mp4a:
                $0.parse()
                mp4a = $0 as! Mp4a
            case .avc1:
                $0.parse()
                avc1 = $0 as! Avc1
            default:
                assertionFailure("no type")
            }
           
            
        }
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
    }
    
   /* init(version: Int,
         flags: Int,
         entryCount: Int,
         other: Int) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.other = other
    }*/
}

class Avc1: HalfContainer {
    var type: ContainerType = .avc1
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    var children: [Container] = []
    
    var referenceIndex = 0
    var width = 0
    var height = 0
    var compressor = ""
    
    var avcc = Avcc()

    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            $0.parse()
            self.avcc = $0 as! Avcc
        }
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
    var segmentParams: [Data] = []
    var pictureParams: [Data] = []
    
    
    func parse() {
        print("\(type) is parsing..")
    }
}
/*
[mp4a] size=8+82
data_reference_index = 1
channel_count = 2
sample_size = 16
sample_rate = 44100

[esds] size=12+42
[ESDescriptor] size=5+37
es_id = 2
stream_priority = 0
[DecoderConfig] size=5+23
stream_type = 5
object_type = 64
up_stream = 0
buffer_size = 0
max_bitrate = 128000
avg_bitrate = 2099
DecoderSpecificInfo = 12 10 56 e5 00
[Descriptor:06] size=5+1

*/
class Esds: HalfContainer {
    var type: ContainerType = .avc1
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    var children: [Container] = []
    
    var esDescriptor = EsDescriptor()
    
    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            $0.parse()
            self.esDescriptor = $0 as! EsDescriptor
        }
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
    }
}

class Mp4a: HalfContainer {
    var type: ContainerType = .avc1
    var size: Int = 0
    var data: Data = Data()
    var offset: UInt64 = 0
    var children: [Container] = []
    
    var dataReferenceIndex = 0
    var channelCount = 0
    var sampleSize = 0
    var sampleRate = 0
    
    var esds = Esds()
    
    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            $0.parse()
            self.esds = $0 as! Esds
        }
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let sampleCount = data.subdata(in: (8 + 8 * i)..<(12 + 8 * i)).convertToInt
            let sampleDelta = data.subdata(in: (12 + 8 * i)..<(16 + 8 * i)).convertToInt
            self.sampleCounts.append(sampleCount)
            self.sampleDeltas.append(sampleDelta)
        }
    }
    
   /* init(version: Int,
         flags: Int,
         entryCount: Int,
         sampleCounts: [Int],
         sampleDelta: [Int]) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.sampleCounts = sampleCounts
        self.sampleDelta = sampleDelta
    }*/
}
    
class Stss: Container {
    
    var type: ContainerType = .stss
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var sampleNumbers: [Int] = []
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let sample = data.subdata(in: (8 + 4 * i)..<(12 + 4 * i)).convertToInt
            self.sampleNumbers.append(sample)
        }
    }
    
    /*init(version: Int,
         flags: Int,
         entryCount: Int,
         sampleNumber: [Int]) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.sampleNumber = sampleNumber
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let firstChunk = data.subdata(in: (8 + 12 * i)..<(12 + 12 * i)).convertToInt
            let samplesPerChunk = data.subdata(in: (12 + 12 * i)..<(16 + 12 * i)).convertToInt
            let sampleDescriptionIndex = data.subdata(in: (16 + 12 * i)..<(20 + 12 * i)).convertToInt
            firstChunks.append(firstChunk)
            samplesPerChunks.append(samplesPerChunk)
            sampleDescriptionIndexes.append(sampleDescriptionIndex)
        }
    }
    
   /* init(version: Int,
         flags: Int,
         entryCount: Int,
         firstChunk: [Int],
         samplesPerChunk: [Int],
         sampleDescriptionIndex: [Int]) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.firstChunk = firstChunk
        self.samplesPerChunk = samplesPerChunk
        self.sampleDescriptionIndex = sampleDescriptionIndex
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.samplesSize = dataArray[2].convertToInt
        self.sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                
                    let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                    self.entrySizes.append(entry)
            }
        }
    }
    /*init(version: Int,
         flags: Int,
         entryCount: [Int],
         sampleCount: Int,
         samplesSize: Int) {
        
        self.version = version
        self.flags = flags
        self.entrySize = entryCount
        self.sampleCount = sampleCount
        self.samplesSize = samplesSize
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.samplesSize = dataArray[2].convertToInt
        self.sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                self.entrySizes.append(entry)
            }
        }
    }
    /*init(version: Int,
     flags: Int,
     entryCount: [Int],
     sampleCount: Int,
     samplesSize: Int) {
     
     self.version = version
     self.flags = flags
     self.entrySize = entryCount
     self.sampleCount = sampleCount
     self.samplesSize = samplesSize
     }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.samplesSize = dataArray[2].convertToInt
        self.sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                self.entrySizes.append(entry)
            }
        }
    }
    /*init(version: Int,
     flags: Int,
     entryCount: [Int],
     sampleCount: Int,
     samplesSize: Int) {
     
     self.version = version
     self.flags = flags
     self.entrySize = entryCount
     self.sampleCount = sampleCount
     self.samplesSize = samplesSize
     }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.samplesSize = dataArray[2].convertToInt
        self.sampleCount = dataArray[3].convertToInt
        if samplesSize == 0 {
            for i in 0..<sampleCount {
                
                let entry = data.subdata(in: (12 + 4 * i)..<(16 + 4 * i)).convertToInt
                self.entrySizes.append(entry)
            }
        }
    }
    /*init(version: Int,
     flags: Int,
     entryCount: [Int],
     sampleCount: Int,
     samplesSize: Int) {
     
     self.version = version
     self.flags = flags
     self.entrySize = entryCount
     self.sampleCount = sampleCount
     self.samplesSize = samplesSize
     }*/
}
    
class Stco: Container {
    
    var type: ContainerType = .stco
    var size: Int = 0
    var data: Data = Data()
    
    var version: Int = 0
    var flags: Int = 0
    var entryCount: Int = 0
    var chunkOffsets: [Int] = []
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        let dataArray = data.slice(in: [1,3,4])
        self.version = dataArray[0].convertToInt
        self.flags = dataArray[1].convertToInt
        self.entryCount = dataArray[2].convertToInt
        for i in 0..<entryCount {
            let chunkOffset = data.subdata(in: (8 + 4 * i)..<(12 + 4 * i)).convertToInt
            self.chunkOffsets.append(chunkOffset)
        }
    }
    /*init(version: Int,
         flags: Int,
         entryCount: Int,
         chunkOffset: [Int]) {
        
        self.version = version
        self.flags = flags
        self.entryCount = entryCount
        self.chunkOffset = chunkOffset
    }*/
}

class Udta: HalfContainer {
    var offset: UInt64 = 0
    
    
    var type: ContainerType = .udta
    var size: Int = 0
    var data: Data = Data()
    
    var meta: Meta = Meta()
    
    var children: [Container] = []
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            if $0.type == .meta {
                    $0.parse()
                    self.meta = $0 as! Meta
            }
        }
        print(type)
    }
    
    /*init(meta: Meta) {
        self.meta = meta
    }*/
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
    
    init() {}
    
    func parse() {
        print("\(type) is parsing..")
        children.forEach {
            if $0.type == .hdlr {
                $0.parse()
                self.handler = $0 as! Hdlr
            }
        }
    }
    /*init(version: Int, flag: Int, handler: Hdlr) {
        self.version = version
        self.flag = flag
        self.handler = handler
    }*/
}

struct Chunk {
    var sampleDescriptionIndex: Int = 0
    var firstSample: Int = 0
    var sampleCount: Int = 0
    var startSample: Int = 0
    var offset: Int = 0
    
    init() {}
    
    /*init(sampleDescriptionIndex: Int,
         firstSample: Int,
         sampleCount: Int,
         offset: Int) {
        self.sampleDescriptionIndex = sampleDescriptionIndex
        self.firstSample = firstSample
        self.sampleCount = sampleCount
        self.offset = offset
    }*/
}

struct Sample {
    var size: Int = 0
    var offset: Int = 0
    var startTime: Int = 0
    var duration: Int = 0
    var compositionTimeOffset: Int = 0
    
    init() {}
    
    /*init(size: Int,
         offset: Int,
         startTime: Int,
         duration: Int,
         cto: Int) {
        self.size = size
        self.offset = offset
        self.startTime = startTime
        self.duration = duration
        self.cto = cto
    }*/
    
}
