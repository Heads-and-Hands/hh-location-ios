//
//  ViewController.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import UIKit
import CoreLocation
import KalmanFilter

class ViewController: UIViewController, CLLocationManagerDelegate, ApiManagerDelegate {
    
    let countSignalsForFilter = 5
    
    var beaconsParameters: [BeaconParameters] = []
    
    var beaconsSignals:[NSNumber: [Int]] = [:]
    
    var lastNearestUId: NSNumber = 0
    
    var nearBeaconIdLabel = UILabel()
    var distanceToNearBeaconLabel = UILabel()
    
    var myBeaconRegion: CLBeaconRegion?
    let locationManager = CLLocationManager()
    let apiManager = ApiManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.red
        
        if (CLLocationManager.authorizationStatus() ==  .notDetermined) {
            locationManager.requestAlwaysAuthorization()
        }
        
        let deviceIdLabel = UILabel()
        deviceIdLabel.textAlignment = .center
        deviceIdLabel.numberOfLines = 0
        deviceIdLabel.text = "Devise ID: \(String(describing: UIDevice.current.identifierForVendor?.uuidString))"
        deviceIdLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deviceIdLabel)
        
        deviceIdLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20.0).isActive = true
        deviceIdLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20.0).isActive = true
        deviceIdLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        deviceIdLabel.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
        
        nearBeaconIdLabel.textAlignment = .center
        nearBeaconIdLabel.text = "Nearest beacon id: Unknown"
        nearBeaconIdLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nearBeaconIdLabel)
        
        nearBeaconIdLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20.0).isActive = true
        nearBeaconIdLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20.0).isActive = true
        nearBeaconIdLabel.topAnchor.constraint(equalTo: deviceIdLabel.bottomAnchor, constant: 40.0).isActive = true
        nearBeaconIdLabel.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
        
        distanceToNearBeaconLabel.textAlignment = .center
        distanceToNearBeaconLabel.text = "Distance: Unknown"
        distanceToNearBeaconLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceToNearBeaconLabel)
        distanceToNearBeaconLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20.0).isActive = true
        distanceToNearBeaconLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20.0).isActive = true
        distanceToNearBeaconLabel.topAnchor.constraint(equalTo: nearBeaconIdLabel.bottomAnchor, constant: 20.0).isActive = true
        distanceToNearBeaconLabel.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        apiManager.delegate = self
        apiManager.requestBeaconParametrs()
    }
    
    func startPositionTracking() {
        locationManager.delegate = self
        
        let uuid = UUID.init(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")
        if let u = uuid {
            myBeaconRegion = CLBeaconRegion.init(proximityUUID: u, identifier: "ru.handh.HHLocation.ios")
            if let b = myBeaconRegion {
                
                b.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: b)
                locationManager.startRangingBeacons(in: b)
            } else {
                print("Error: Сould not create region")
                presentAlert(title: "Error", message: "Сould not create region", reloadFunction: nil)
            }
            
        } else {
            print("Error: Error in the UUID region")
            presentAlert(title: "Error", message: "Error in the UUID region", reloadFunction: nil)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let b = myBeaconRegion {
            locationManager.startRangingBeacons(in: b)
        } else {
            print("Error: Error start ranging beacons")
            presentAlert(title: "Error", message: "Error start ranging beacons", reloadFunction: nil)
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        view.backgroundColor = UIColor.red
        nearBeaconIdLabel.text = "Nearest beacon id: Unknown"
        distanceToNearBeaconLabel.text = "Distance: Unknown"
        
        if let b = myBeaconRegion {
            locationManager.stopRangingBeacons(in: b)
        } else {
            print("Error: Error stop ranging beacons")
            presentAlert(title: "Error", message: "Error stop ranging beacons", reloadFunction: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        for beacon in beacons {
            switch beacon.proximity {
            case .immediate, .near, .far:
                if var signals = beaconsSignals[beacon.minor] {
                    if signals.count == countSignalsForFilter {
                        signals.remove(at: 0)
                    }
                    signals.append(beacon.rssi)
                    beaconsSignals[beacon.minor] = signals
                } else {
                    beaconsSignals[beacon.minor] = [beacon.rssi]
                }
                
                signalFiltering()
                break
                
            default:
                break
            }
        }
    }
    
    // MARK: - Private
    
    fileprivate func signalFiltering() {
        
        var filteredSignal: [SignalModel] = []
        
        for signals in beaconsSignals {
            if signals.value.count == countSignalsForFilter {
                var filter = KalmanFilter(stateEstimatePrior: 0.0, errorCovariancePrior: 1)
                
                for signal in signals.value {
                    let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: 0)
                    let update = prediction.update(measurement: Double(signal), observationModel: 1, covarienceOfObservationNoise: 0.1)
                    
                    filter = update
                }
                
                filteredSignal.append(SignalModel(number: signals.key, signal: Int(filter.stateEstimatePrior)))
            }
        }
        
        positioning(signals: filteredSignal)
    }
    
    fileprivate func calculateDistance(signal: SignalModel) -> Double? {
        
        if signal.signal != 0, let correction = beaconParameters(uid: signal.number)?.correction {
            let ratio = Double(signal.signal)*1.0/Double(correction)
            
            if (ratio < 1.0) {
                return pow(ratio, 10)
            } else {
                return 0.89976*pow(ratio, 7.7095) + 0.111
            }
        }
        
        return nil;
    }
    
    fileprivate func positioning(signals: [SignalModel]) {
        var distances: [NSNumber: Double] = [:]
        for signal in signals {
            if let distance = calculateDistance(signal: signal) {
                distances[signal.number] = distance
            }
        }
        
        let sortedDistances = distances.sorted(by: {$0.value < $1.value})
        
        if let nearDistance = sortedDistances.first, nearDistance.value < 10.0, nearDistance.key != lastNearestUId {
            showPosition(nearDistance: nearDistance)
        }
    }
    
    fileprivate func showPosition(nearDistance: (key: NSNumber, value: Double)) {
        
        
        
        if let beaconParameters = beaconParameters(uid: nearDistance.key) {
            nearBeaconIdLabel.text = "Nearest beacon id: \(nearDistance.key)"
            distanceToNearBeaconLabel.text = "Distance: \(nearDistance.value)"
            view.backgroundColor = UIColor.blue
            
            lastNearestUId = beaconParameters.uId
            apiManager.sendLocation(posX: beaconParameters.posX, posY: beaconParameters.posY)
            
        }
    }
    
    fileprivate func beaconParameters(uid: NSNumber) -> BeaconParameters? {
        for parameters in beaconsParameters {
            if parameters.uId == uid {
                return parameters
            }
        }
        
        return nil
    }
    
    // MARK: - ApiManagerDelegate
    
    func updateBeaconsParameters(beaconsParameters: [BeaconParameters]) {
        self.beaconsParameters = beaconsParameters
        startPositionTracking()
    }
    
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        if reloadFunction != nil {
            alert.addAction(UIAlertAction(title: "Refresh", style: .default, handler: reloadFunction))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        } else {
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        }
        
        self.present(alert, animated: true, completion: nil)
    }
}
