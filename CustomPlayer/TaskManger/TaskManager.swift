//
//  TaskManager.swift
//  CustomPlayer
//
//  Created by bumslap on 05/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol TaskMangerDelegate: class {
    func requestMoreTask() -> Operation
}

class TaskManager {
    private let taskToleranceCount = 30
    private let decodeQueue: DispatchQueue = DispatchQueue(label: "decodeQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
     private let processQueue: DispatchQueue = DispatchQueue(label: "processQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    private var tasks: [DispatchWorkItem] = []
    private var isInterrupted: Bool = false
    private var taskThresholdCount = 0
   
    
    func add(task: DispatchWorkItem) -> Bool {
        
            if isInterrupted {
                taskThresholdCount += 1
                if taskThresholdCount >= taskToleranceCount {
                    return false
                }
            }
            //tasks.append(task)
            decodeQueue.sync(execute: task)
            
        
        return true
    }
    
    func interruptCall() {
        isInterrupted = true
    }
    
    func reset() {
        isInterrupted = false
        taskThresholdCount = 0
    }
    
    func pauseTask() {
        decodeQueue.suspend()
    }
    
    func resumeTask() {
        decodeQueue.resume()
    }
    
    func cancelAllItems() {
        tasks.forEach {
            $0.cancel()
        }
    }
}


