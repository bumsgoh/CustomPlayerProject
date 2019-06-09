//
//  AsyncOperation.swift
//  CustomPlayer
//
//  Created by bumslap on 05/06/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

protocol OperationStateDelegate: class {
    func stopRunnuing()
}

class TSOperation: Operation {
    
    typealias CompletionType = (@escaping (Result<Bool?, Error>) -> Void) -> Void
    
    weak var delegate: OperationStateDelegate?
    
    private let operation: CompletionType
    
    private let fetchingQueue: DispatchQueue = DispatchQueue(label: "com.OperationSyncQueue")
    
    @objc private enum State: Int {
        case ready
        case executing
        case finished
    }
    
    private var _state = State.ready
    private let stateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".op.state", attributes: .concurrent)
    
    @objc private dynamic var state: State {
        get { return stateQueue.sync { _state } }
        set { stateQueue.sync(flags: .barrier) { _state = newValue } }
    }
    
    public override var isAsynchronous: Bool { return true }
    open override var isReady: Bool {
        return super.isReady && state == .ready
    }
    
    public override var isExecuting: Bool {
        return state == .executing
    }
    
    public override var isFinished: Bool {
        return state == .finished
    }
    
    init(operation: @escaping CompletionType) {
        self.operation = operation
        super.init()
    }
    
    open override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if ["isReady",  "isFinished", "isExecuting"].contains(key) {
            return [#keyPath(state)]
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }
    
    public override func start() {
        if isCancelled {
            finish()
            return
        }
        self.state = .executing
        main()
    }
    open override func main() {
        
            let semaphore = DispatchSemaphore(value: 0)
            
            self.operation() { [weak self] (result) in
                
                switch result {
                case .failure:
                    semaphore.signal()
                    self?.delegate?.stopRunnuing()
                    self?.finish()
                case .success(let value):
                    semaphore.signal()
                    if value == nil {
                        self?.delegate?.stopRunnuing()
                        self?.finish()
                    }
                }
                
            }
        semaphore.wait()
        
      
    }
    
    public final func finish() {
        if isExecuting {
            state = .finished
        }
    }
}
