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
    
    private var needMoreTask: Bool = true
    private var currentTask: Operation?
    
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    weak var delegate: TaskMangerDelegate?
    
    func work() -> Bool {
        guard let delegate = delegate else { return false }
        if !needMoreTask { return false }
//        if queue.operations.count > 0 {
//            operation.addDependency(operationQueue.operations.last!)
//            // Print dependencies
//            print("\(operation.name!) should finish after \(operation.dependencies.first!.name!)")
//        }
      //  currentTask = delegate.requestMoreTask()
      //  currentTask?.start()
        
        queue.addOperations([delegate.requestMoreTask()], waitUntilFinished: true)
      //  queue.wait
        
        return true
    }
    
    func add(task: Operation) {

        queue.addOperation(task)
    }
    
    func addWithDependency(task: Operation) {
        if queue.operations.count > 0 {
             guard let lastOperation = queue.operations.last else { return }
            task.addDependency(lastOperation)
        }
        queue.addOperation(task)
    }
    
    func pauseTask() {
       // if !queue.isSuspended  {
            queue.isSuspended = true
      //  }
    }
    
    func resumeTask() {
       // if queue.isSuspended {
            queue.isSuspended = false
       // }
    }
}

extension TaskManager: OperationStateDelegate {
    func stopRunnuing() {
        needMoreTask = false
    }
}
