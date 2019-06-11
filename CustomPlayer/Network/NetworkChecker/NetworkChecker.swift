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
    private let historySize: Int = 5
    
    private var startTime: Date = Date()
    private var elapsedTime: Float = 0
    private var dataLength: Float = 0
    var currentNetworkSpeed: Double = 0
    var networkSpeedHistory: [Double] = []
    
    
    private init() {}
    
    func setStartTime() {
        startTime = Date()
    }
    
    func stopTimeTracking() {
        elapsedTime = Float(Date().timeIntervalSince(startTime))
    }
    
    func getDataLength(size: Int) {
        dataLength = Float(size) / 1000000.0
    }
    
    func calculateNetworkSpeed() {
        let speed = dataLength / elapsedTime
        currentNetworkSpeed = Double(speed)
        if networkSpeedHistory.count < historySize {
            networkSpeedHistory.append(currentNetworkSpeed)
        } else {
            networkSpeedHistory.removeFirst()
            networkSpeedHistory.append(currentNetworkSpeed)
        }
    }
    
    
}

