//
//  CancellableBlockOperation.swift
//  Simple Comic
//
//  Created by Tomioka Taichi on 2020/04/08.
//

import Foundation

class CancellableBlockOperation: Operation {
    public convenience init(block: @escaping (_ current: CancellableBlockOperation) -> Void) {
        self.init()
        self.addExecutionBlock(block)
    }

    open func addExecutionBlock(_ block: @escaping (_ current: CancellableBlockOperation) -> Void) {
        executionBlocks.append(block)
    }

    open var executionBlocks: [@convention(block) (_ current: CancellableBlockOperation) -> Void] = []

    override func main() {
        for block in executionBlocks {
            block(self)
        }
    }
    
    var _isCancelled: Bool = false
    override var isCancelled: Bool { _isCancelled }
    override func cancel() {
        _isCancelled = true
    }
}

extension OperationQueue {
    func addOperation(_ block: @escaping (_ :CancellableBlockOperation) -> Void) {
        self.addOperation(CancellableBlockOperation(block: block))
    }
}
