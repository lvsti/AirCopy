//
//  StateMachine.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

class StateMachine<StateType: Hashable> {
    typealias Transition = (nextState: StateType, condition: () -> Bool, action: () -> Void)
    let transitions: [StateType: [Transition]]
    
    private var _currentState: StateType
    var currentState: StateType { return _currentState }
    
    init(initialState: StateType, transitions: [StateType: [Transition]]) {
        self.transitions = transitions
        _currentState = initialState
    }
    
    func step() {
        loop: while true {
            guard let possibleTransitions = transitions[_currentState] else {
                return
            }
            
            for transition in possibleTransitions {
                if transition.condition() {
                    _currentState = transition.nextState
                    transition.action()
                    continue loop
                }
            }
        }
    }
}

