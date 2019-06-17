//
//  NetworkLoadPolicy.swift
//  CustomPlayer
//
//  Created by USER on 03/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol NetworkPolicyDelegate: class {
    func currentNetworkSpeed() -> Double
    func numberOfPlaylist() -> Int
    func samplingNetworSpeedkHistory(limit number: Int) -> [Double]
   
}

class NetworkLoadPolicy {
    
    weak var delegate: NetworkPolicyDelegate?
    private var currentGear: Int = 0
    private var currentLevel: NetworkSpeedLevel = .verySlow

    private func calculateCurrentNetworkSpeedLevel() -> NetworkSpeedLevel {
        guard let networkSpeed = delegate?.currentNetworkSpeed() else {
            return .verySlow
        }
        print("speed \(networkSpeed)")
        var level: NetworkSpeedLevel = .verySlow
        switch networkSpeed {
        case 0 ..< 0.5:
            level = .verySlow
        case 0.5 ..< 20:
            level = .slow
        case 20 ..< 28:
            level = .normal
        case 28 ..< 500:
            level = .fast
        case 500 ..< 10000:
            level = .veryFast
        default:
            level = .verySlow
        }
        return level
    }
    
    func selectFirstPlaylistGear() -> Int {
        guard let numberOfPlaylist = delegate?.numberOfPlaylist() else { return 0 }
        let level = calculateCurrentNetworkSpeedLevel()
        var gear: Int = 0

        switch level {
        case .verySlow:
            gear = 0
        case .slow:
            gear = numberOfPlaylist < 1 ? numberOfPlaylist : 1
        case .normal:
            gear = numberOfPlaylist < 2 ? numberOfPlaylist : 2
        case .fast:
            gear = numberOfPlaylist < 3 ? numberOfPlaylist : 3
        case .veryFast:
            gear = numberOfPlaylist < 4 ? numberOfPlaylist : 4
        }
        currentGear = gear
        currentLevel = level
        return gear
    }
    
    
    func shouldUpdateGear() -> Int {
        let hasLevelChanged = calculateCurrentNetworkSpeedLevel() != currentLevel
        
        guard let numberOfPlaylist = delegate?.numberOfPlaylist() else {
            return -1
        }
        guard let sampleData = delegate?.samplingNetworSpeedkHistory(limit: 10) else {
            return -1
        }
        let isIncreasing = isTrendLineIncreasing(data: sampleData)
        if isIncreasing && hasLevelChanged {
            let nextGear = currentGear + 1
            let gear = (numberOfPlaylist - 1) < nextGear ? numberOfPlaylist - 1 : nextGear
            return gear
        } else if !isIncreasing && hasLevelChanged {
            let nextGear = currentGear - 1
            let gear = 0 > nextGear ? 0 : nextGear
            return gear
        } else {
            return currentGear
        }
    }
    
}

enum NetworkSpeedLevel: Double {
    case verySlow
    case slow
    case normal
    case fast
    case veryFast
}
