//
//  ApiManager.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import UIKit
import Alamofire

protocol ApiManagerDelegate: class {
    func updateBeaconsParameters(beaconsParameters: [BeaconParameters])
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?)
}

class ApiManager {
    
    var delegate: ApiManagerDelegate?
    
    func requestBeaconParametrs() {
        request("http://d.handh.ru:8887/beacon?token=fsdf", method: .get) .responseJSON { responseJSON in
            
            switch responseJSON.result {
            case .success(let value):
                
                guard let jsonArray = value as? Array<[String: Any]> else { return }
                
                var beaconsParameters: [BeaconParameters] = []
                
                for jsonObject in jsonArray {
                    guard
                        let id = jsonObject["ID"] as? NSNumber,
                        let uId = jsonObject["Uid"] as? NSNumber,
                        let name = jsonObject["Name"] as? String,
                        let correction = jsonObject["Correction"] as? Int,
                        let posX = jsonObject["PosX"] as? Double,
                        let posY = jsonObject["PosY"] as? Double
                        else {
                            return
                    }
                    let beaconParameters = BeaconParameters.init(id: id, uId: uId, name: name, correction: correction, posX: posX, posY: posY)
                    beaconsParameters.append(beaconParameters)
                }
                self.delegate?.updateBeaconsParameters(beaconsParameters: beaconsParameters)
                
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
                self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: { _ in
                    self.requestBeaconParametrs()
                })
            }
        }
    }
    
    func sendLocation(posX: Double, posY: Double) {
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            let parameters: [String : Any] = ["DeviceId": deviceId,
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
            self.delegate?.presentAlert(title: "Error", message: "Unable to send location data", reloadFunction: { _ in
                self.sendLocation(posX: posX, posY: posY)
            })
        }
    }
}
