//
//  ApiManager.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Alamofire
import UIKit

import CoreLocation
import KalmanFilter

typealias AllDevicesCallback = ([Device]) -> Void
typealias RegisterDeviceCallback = (Bool) -> Void

class ApiManager: NSObject{
    
    var myBeaconRegion: CLBeaconRegion?
    let locationManager = CLLocationManager()
    let deviceId = UIDevice.current.identifierForVendor?.uuidString
    let deviceName = UIDevice.current.name
    
    let countSignalsForFilter = 5
    let maxDistance = 7.0
    
    var beaconsParameters: [Beacon] = []
    var beaconsSignals: [Int: [Int]] = [:]
    var lastNearestUId: Int = 0
    
    weak var delegate: ApiManagerDelegate?

    private let host = "http://d.handh.ru:8887"
    private let token = "fsdf"
    
    override init() {
        super.init()
        requestBeaconParameters()
    }

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
                
                self.beaconsParameters = beacons
                self.startPositionTracking()

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
                    self.delegate?.completeRequest(error: true)
                    self.delegate?.presentAlert(title: "Error", message: error.localizedDescription, reloadFunction: {
                        _ in
                        self.sendLocation(posX: posX, posY: posY)
                    })
                } else {
                    self.delegate?.completeRequest(error: false)
                }
            }
        } else {
            print("Error: Unable to send location data")
            self.delegate?.completeRequest(error: true)
            delegate?.presentAlert(title: "Error", message: "Unable to send location data", reloadFunction: {
                _ in
                self.sendLocation(posX: posX, posY: posY)
            })
        }
    }
}

// MARK: - Private metods

extension ApiManager {
    private func startPositionTracking() {
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
        
        locationManager.delegate = self
        
        if let uuid = UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825") {
            myBeaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "ru.handh.HHLocation.ios")
            if let region = myBeaconRegion {
                region.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: region)
                locationManager.startRangingBeacons(in: region)
            } else {
                print("Error: Сould not create region")
                delegate?.presentAlert(title: "Error", message: "Сould not create region", reloadFunction: nil)
            }
        } else {
            print("Error: Error in the UUID region")
            delegate?.presentAlert(title: "Error", message: "Error in the UUID region", reloadFunction: nil)
        }
    }
    
    private func signalFiltering() {
        var filteredSignal: [Signal] = []
        
        for signals in beaconsSignals where signals.value.count == countSignalsForFilter {
            var filter = KalmanFilter(stateEstimatePrior: 0.0, errorCovariancePrior: 1)
            
            for signal in signals.value {
                let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: 0)
                let update = prediction.update(measurement: Double(signal), observationModel: 1, covarienceOfObservationNoise: 0.1)
                
                filter = update
            }
            
            filteredSignal.append(Signal(number: signals.key, signal: Int(filter.stateEstimatePrior)))
        }
        
        positioning(signals: filteredSignal)
    }
    
    private func calculateDistance(signal: Signal) -> Double? {
        if signal.signal != 0, let correction = beaconParameters(uid: signal.number)?.correction {
            let ratio = Double(signal.signal) * 1.0 / Double(correction)
            
            if ratio < 1.0 {
                return pow(ratio, 10)
            } else {
                return 0.89976 * pow(ratio, 7.7095) + 0.111
            }
        }
        
        return nil
    }
    
    private func positioning(signals: [Signal]) {
        var distances: [Int: Double] = [:]
        for signal in signals {
            if let distance = calculateDistance(signal: signal) {
                distances[signal.number] = distance
            }
        }
        
        let sortedDistances = distances.sorted(by: { $0.value < $1.value })
        
        if let nearDistance = sortedDistances.first, nearDistance.value < maxDistance, nearDistance.key != lastNearestUId {
            showPosition(nearDistance: nearDistance)
        }
    }
    
    private func showPosition(nearDistance: (key: Int, value: Double)) {
        if let beaconParameters = beaconParameters(uid: nearDistance.key) {
            delegate?.detectedBeacon(beacon: beaconParameters, distance: nearDistance.value)
            
            lastNearestUId = beaconParameters.uid
            sendLocation(posX: beaconParameters.posX, posY: beaconParameters.posY)
        }
    }
    
    private func beaconParameters(uid: Int) -> Beacon? {
        return beaconsParameters.first(where: { $0.uid == uid })
    }

}

// MARK: - CLLocationManagerDelegate

extension ApiManager: CLLocationManagerDelegate {
    
    func locationManager(_: CLLocationManager, didEnterRegion _: CLRegion) {
        if let region = myBeaconRegion {
            locationManager.startRangingBeacons(in: region)
        } else {
            print("Error: Error start ranging beacons")
            delegate?.presentAlert(title: "Error", message: "Error start ranging beacons", reloadFunction: nil)
        }
    }
    
    func locationManager(_: CLLocationManager, didExitRegion _: CLRegion) {
        delegate?.switchToErrorState()
        
        if let region = myBeaconRegion {
            locationManager.stopRangingBeacons(in: region)
        } else {
            print("Error: Error stop ranging beacons")
            delegate?.presentAlert(title: "Error", message: "Error stop ranging beacons", reloadFunction: nil)
        }
    }
    
    func locationManager(_: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in _: CLBeaconRegion) {
        for beacon in beacons {
            let minor = beacon.minor.intValue
            switch beacon.proximity {
            case .immediate, .near, .far:
                if var signals = beaconsSignals[minor] {
                    if signals.count == countSignalsForFilter {
                        signals.remove(at: 0)
                    }
                    signals.append(beacon.rssi)
                    beaconsSignals[minor] = signals
                } else {
                    beaconsSignals[minor] = [beacon.rssi]
                }
                
                signalFiltering()
            default:
                break
            }
        }
    }
}

// MARK: - Protocol ApiManagerDelegate

protocol ApiManagerDelegate: class {
    func detectedBeacon(beacon: Beacon, distance: Double)
    func completeRequest(error: Bool)
    func switchToErrorState()
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?)
}
