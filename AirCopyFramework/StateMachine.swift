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
    private let transitions: TransitionMapType
    
    public private(set) var currentState: StateType
    
    init(initialState: StateType, transitions: TransitionMapType) {
        self.transitions = transitions
        currentState = initialState
    }
    
    func step() {
        var didTransition = true
        
        while didTransition {
            didTransition = false
            
            guard let possibleTransitions = transitions[currentState] else {
                return
            }
            
            for transition in possibleTransitions {
                if transition.condition() {
                    currentState = transition.nextState
                    transition.action()
                    didTransition = true
                }
            }
        }
    }
}

