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
    private let taskToleranceCount = 20
    private let decodeQueue: DispatchQueue = DispatchQueue(label: "decodeQueue")
     private let fetchOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = QualityOfService.userInitiated
        return queue
     }()
     private let lockQueue: DispatchQueue = DispatchQueue(label: "lcokQueue")
    private var tasks: [DispatchWorkItem] = []
    private var isInterrupted: Bool = false
    private var taskThresholdCount = 0
   
    
    func add(task: BlockOperation) -> Bool {
        
            if isInterrupted {
                lockQueue.async {
                     self.taskThresholdCount += 1
                }
                if taskThresholdCount >= taskToleranceCount {
                   // task.cancel()
                    return false
                }
            }
           // tasks.append(task)
           // decodeQueue.sync(execute: task)
    
        fetchOperationQueue.addOperations([task], waitUntilFinished: true)
       
            
        
        return true
    }
    
    func interruptCall() {
        lockQueue.async {
            self.isInterrupted = true
        }
    }
    
    func reset() {
     
        lockQueue.async {
            self.isInterrupted = false
            self.taskThresholdCount = 0
        }
       
      
    }
    
    func pauseTask() {
       // decodeQueue.suspend()
          fetchOperationQueue.isSuspended = true
    }
    
    func resumeTask() {
       // decodeQueue.resume()
         fetchOperationQueue.isSuspended = false
    }
    
    func cancelAllItems() {
        
       fetchOperationQueue.cancelAllOperations()
    }
}


