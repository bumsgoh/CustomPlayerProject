//
//  NetworkChecker.swift
//  CustomPlayer
//
//  Created by USER on 30/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class NetworkChecker {
    
    static let shared = NetworkChecker()
    
    private var startTime: Date = Date()
    private var elapsedTime: Float = 0
    private var dataLength: Float = 0
    
    private init() {}
    
    func setStartTime() {
        startTime = Date()
    }
    
    func stopTimeTracking() {
        elapsedTime = Float(Date().timeIntervalSince(startTime))
    }
    
    func getDataLength(size: Int) {
        dataLength = Float(size) / 1000000.0
        calculateNetworkSpeed(by: .low)
    }
    
    func calculateNetworkSpeed(by policy: NetworkPolicy) {
      
        let speed = dataLength / elapsedTime
        print(speed)
    }
}

enum NetworkPolicy {
    case low
}
