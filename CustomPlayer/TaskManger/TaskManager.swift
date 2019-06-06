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
    
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    weak var delegate: TaskMangerDelegate?
    
    func work() -> Bool {
        guard let delegate = delegate else { return false }
        if !needMoreTask { return false }
        queue.addOperation(delegate.requestMoreTask())
       // queue.addOperations([delegate.requestMoreTask()], waitUntilFinished: true)
    
        return true
    }
}

extension TaskManager: OperationStateDelegate {
    func stopRunnuing() {
        needMoreTask = false
    }
}
