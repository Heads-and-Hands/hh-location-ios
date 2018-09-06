//
//  LocationManager.swift
//  HHLocation
//
//  Created by HeadsAndHands on 05.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import Foundation

import CoreLocation
import KalmanFilter


class LocationManager: NSObject {
    
    var delegate: LocationManagerDelegate?
    
    var myBeaconRegion: CLBeaconRegion?
    
    private(set) lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        return locationManager
    }()
    
    let deviceId = UIDevice.current.identifierForVendor?.uuidString
    let deviceName = UIDevice.current.name
    
    let countSignalsForFilter = 5
    let maxDistance = 7.0
    
    var beaconsParameters: [Beacon] = []
    var beaconsSignals: [Int: [Int]] = [:]
    var lastNearestUId: Int = 0
    
    override init() {
        super.init()
        startPositionTracking()
    }
}

// MARK: - Private metods

extension LocationManager {
    private func startPositionTracking() {
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
        
        if let uuid = UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825") {
            let beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "ru.handh.HHLocation.ios")
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyEntryStateOnDisplay = true
            locationManager.startMonitoring(for: beaconRegion)
            locationManager.startRangingBeacons(in: beaconRegion)
            myBeaconRegion = beaconRegion
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
            lastNearestUId = beaconParameters.uid
            delegate?.detectedBeacon(beacon: beaconParameters, distance: nearDistance.value)
        }
    }
    
    private func beaconParameters(uid: Int) -> Beacon? {
        return beaconsParameters.first(where: { $0.uid == uid })
    }
    
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
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
        
        if (UserDefaults.standard.bool(forKey: "locationDisable")) {
            return
        }
        
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

// MARK: - Protocol LocationManagerDelegate

protocol LocationManagerDelegate: class {
    func detectedBeacon(beacon: Beacon, distance: Double)
    func switchToErrorState()
    func presentAlert(title: String, message: String, reloadFunction: ((UIAlertAction) -> Void)?)
}
