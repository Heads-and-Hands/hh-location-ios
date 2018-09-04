//
//  ApiManager.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Alamofire
import UIKit

protocol ApiManagerDelegate: class {
    func updateBeaconsParameters(beaconsParameters: [Beacon])
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?)
}

class ApiManager {
    weak var delegate: ApiManagerDelegate?

    func requestBeaconParametrs() {
        request("http://d.handh.ru:8887/beacon?token=fsdf", method: .get).responseJSON { responseJSON in

            switch responseJSON.result {
            case let .success(value):

                guard let jsonArray = value as? [[String: Any]] else { return }

                var beaconsParameters: [Beacon] = []

                for jsonObject in jsonArray {
                    guard
                        let id = jsonObject["ID"] as? Int,
                        let uId = jsonObject["Uid"] as? Int,
                        let name = jsonObject["Name"] as? String,
                        let correction = jsonObject["Correction"] as? Int,
                        let posX = jsonObject["PosX"] as? Double,
                        let posY = jsonObject["PosY"] as? Double
                        else {
                        return
                    }
                    let beaconParameters = Beacon(id: id, uId: uId, name: name, correction: correction, posX: posX, posY: posY)
                    beaconsParameters.append(beaconParameters)
                }
                self.delegate?.updateBeaconsParameters(beaconsParameters: beaconsParameters)

            case let .failure(error):
                print("Error: \(error.localizedDescription)")
                self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: { _ in
                    self.requestBeaconParametrs()
                })
            }
        }
    }

    func sendLocation(posX: Double, posY: Double) {
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            let parameters: [String: Any] = ["UID": deviceId,
                                             "PosX": posX,
                                             "PosY": posY]

            request("http://d.handh.ru:8887/position?token=fsdf", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: nil).response { response in

                if let error = response.error {
                    print("Error: \(error.localizedDescription)")
                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: { _ in
                        self.sendLocation(posX: posX, posY: posY)
                    })
                }
            }
        } else {
            print("Error: Unable to send location data")
            delegate?.presentAlert(title: "Error", message: "Unable to send location data", reloadFunction: { _ in
                self.sendLocation(posX: posX, posY: posY)
            })
        }
    }
}
