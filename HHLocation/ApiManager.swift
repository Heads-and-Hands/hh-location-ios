//
//  ApiManager.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Alamofire
import UIKit

typealias AllDevicesCallback = ([Device]) -> Void
typealias RegisterDeviceCallback = (Bool) -> Void

class ApiManager {
    weak var delegate: ApiManagerDelegate?

    private let host = "http://d.handh.ru:8887"
    private let token = "fsdf"

    func allDevices(completion: @escaping AllDevicesCallback) {
        request("\(host)/device?token=\(token)", method: .get).responseJSON { responseJSON in
            switch responseJSON.result {
            case .success:
                let jsonEncoder = JSONDecoder()
                guard let data = responseJSON.data,
                    let devices = try? jsonEncoder.decode([Device].self, from: data) else {
                    print("error during received devices parsing")
                    completion([])
                    return
                }
                completion(devices)
            case let .failure(error):
                print("Error: \(error.localizedDescription)")
                completion([])
            }
        }
    }

    func register(_ device: Device, completion: @escaping RegisterDeviceCallback) {
        let jsonEncoder = JSONEncoder()
        do {
            let data = try jsonEncoder.encode(device)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            request("\(host)/device?token=\(token)", method: .post, parameters: json, encoding: JSONEncoding()).responseJSON { responseJSON in
                switch responseJSON.result {
                case .success:
                    completion(true)
                case let .failure(error):
                    print("Error: \(error.localizedDescription)")
                    completion(false)
                }
            }
        } catch {
            completion(false)
        }
    }

    func requestBeaconParameters() {
        request("\(host)/beacon?token=\(token)", method: .get).responseJSON { responseJSON in
            switch responseJSON.result {
            case .success:
                let jsonEncoder = JSONDecoder()

                guard let data = responseJSON.data,
                    let beacons = try? jsonEncoder.decode([Beacon].self, from: data) else {
                    print("error during received beacons parsing")
                    return
                }

                self.delegate?.updateBeaconsParameters(beaconsParameters: beacons)

            case let .failure(error):
                print("Error: \(error.localizedDescription)")
                self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: { _ in
                    self.requestBeaconParameters()
                })
            }
        }
    }

    func sendLocation(posX: Double, posY: Double) {
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            let parameters: [String: Any] = ["UID": deviceId,
                                             "PosX": posX,
                                             "PosY": posY]

            request("\(host)/position?token=\(token)", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: nil).response { response in

                if let error = response.error {
                    print("Error: \(error.localizedDescription)")
                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: {
                        _ in
                        self.sendLocation(posX: posX, posY: posY)
                    })
                }
            }
        } else {
            print("Error: Unable to send location data")
            delegate?.presentAlert(title: "Error", message: "Unable to send location data", reloadFunction: {
                _ in
                self.sendLocation(posX: posX, posY: posY)
            })
        }
    }
}

protocol ApiManagerDelegate: class {
    func updateBeaconsParameters(beaconsParameters: [Beacon])
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?)
}
