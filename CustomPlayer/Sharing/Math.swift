//
//  Math.swift
//  CustomPlayer
//
//  Created by USER on 03/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

func isTrendLineIncreasing(data: [Double]) -> Bool {
    let yAxis = Array(0..<data.count).map { Double($0) }
    let sum1 = average(multiply(yAxis, data)) - average(data) * average(yAxis)
    let sum2 = average(multiply(data, data)) - pow(average(data), 2)
    let slope = sum1 / sum2
    return  slope > 0
}

func average(_ data: [Double]) -> Double {
    return data.reduce(0, +) / Double(data.count)
}

func multiply(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
    return zip(lhs,rhs).map(*)
}

//https://github.com/raywenderlich/swift-algorithm-club/tree/master/Linear%20Regression
