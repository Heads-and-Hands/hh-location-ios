//
//  BeaconParameters.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Foundation

class BeaconParameters {
    
    let id: NSNumber
    let uId: NSNumber
    let name: String
    let correction: Int
    let posX: Double
    let posY: Double
    
    required init(id: NSNumber, uId: NSNumber, name: String, correction: Int, posX: Double, posY: Double) {
        self.id = id
        self.uId = uId
        self.name = name
        self.correction = correction
        self.posX = posX
        self.posY = posY
    }
}
