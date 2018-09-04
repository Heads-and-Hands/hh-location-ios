//
//  SignalModel.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Foundation

class SignalModel {
    
    let number: NSNumber
    let signal: Int
    
    required init(number: NSNumber, signal: Int) {
        self.number = number
        self.signal = signal
    }
}
