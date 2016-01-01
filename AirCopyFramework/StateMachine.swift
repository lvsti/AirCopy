//
//  StateMachine.swift
//  AirCopy
//
//  Created by Tamás Lustyik on 2015. 12. 28..
//  Copyright © 2015. Tamas Lustyik. All rights reserved.
//

import Foundation

struct Transition<StateType> {
    let nextState: StateType
    let condition: () -> Bool
    let action: () -> Void
}

class StateMachine<StateType: Hashable> {
    typealias TransitionMapType = [StateType: [Transition<StateType>]]
    let transitions: TransitionMapType
    
    private var _currentState: StateType
    var currentState: StateType { return _currentState }
    
    init(initialState: StateType, transitions: TransitionMapType) {
        self.transitions = transitions
        _currentState = initialState
    }
    
    func step() {
        var didTransition = true
        
        while didTransition {
            didTransition = false
            
            guard let possibleTransitions = transitions[_currentState] else {
                return
            }
            
            for transition in possibleTransitions {
                if transition.condition() {
                    _currentState = transition.nextState
                    transition.action()
                    didTransition = true
                }
            }
        }
    }
}

