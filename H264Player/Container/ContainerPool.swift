//
//  ContainerPool.swift
//  MPEG-4Parser
//
//  Created by USER on 25/04/2019.
//  Copyright © 2019 bumslap. All rights reserved.
//

import Foundation

class ContainerPool {
    private var containerPool = [String: ContainerType]()
    private var fileContainerPool = [ContainerType: Container]()
    init() {
        
        ContainerType.allCases.forEach {
            containerPool.updateValue($0, forKey: $0.rawValue)
        }
        
    }
    func pullOutContainer(with name: String) throws -> ContainerType {
        guard let container = containerPool[name] else {
            throw NSError(domain: "No container with input name", code: 0)
        }
        return container
    }
    func pullOutFileTypeContainer(with type: ContainerType) -> Container {
        
        switch type {
        case .root:
            return RootType()
        case .ftyp:
            return Ftyp()
        case .free:
            return Free()
        case .mdat:
            return Mdat()
        case .moov:
            return Moov()
        case .iods:
            return Iods()
        case .mvhd:
            return Mvhd()
        case .trak:
            return Trak()
        case .tkhd:
            return Tkhd()
        case .edts:
            return Edts()
        case .elst:
            return Elst()
        case .mdia:
            return Mdia()
        case .mdhd:
            return Mdhd()
        case .hdlr:
            return Hdlr()
        case .minf:
            return Minf()
        case .vmhd:
            return Vmhd()
        case .smhd:
            return Smhd()
        case .dinf:
            return Dinf()
        case .dref:
            return Dref()
        case .stbl:
            return Stbl()
        case .co64:
            return Co64()
        case .ctts:
            return Ctts()
        case .stsd:
            return Stsd()
        case .avc1:
            return Avc1()
        case .avcc:
            return Avcc()
        case .esds:
            return Esds()
        case .mp4a:
            return Mp4a()
        case .stts:
            return Stts()
        case .stss:
            return Stss()
        case .stsc:
            return Stsc()
        case .stsz:
            return Stsz()
        case .stco:
            return Stco()
        case .udta:
            return Udta()
        case .meta:
            return Meta()
        }
    }
}



