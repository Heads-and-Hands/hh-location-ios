//
//  Beacon.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Foundation

struct Beacon: Decodable {
    let uid: Int
    let name: String
    let correction: Int
    let posX: Double
    let posY: Double
}
