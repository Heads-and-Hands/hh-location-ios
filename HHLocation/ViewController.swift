//
//  ViewController.s?wift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import CoreLocation
import KalmanFilter
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate, ApiManagerDelegate {
    let countSignalsForFilter = 5

    var beaconsParameters: [Beacon] = []

    var beaconsSignals: [Int: [Int]] = [:]

    var lastNearestUId: Int = 0

    var nearBeaconIdLabel = UILabel()
    var distanceToNearBeaconLabel = UILabel()

    var myBeaconRegion: CLBeaconRegion?
    let locationManager = CLLocationManager()
    let apiManager = ApiManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 10.0

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor),
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])

        stackView.addArrangedSubview(deviceIdStack)

        nearBeaconIdLabel.textAlignment = .center
        nearBeaconIdLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(nearBeaconIdLabel)

        distanceToNearBeaconLabel.textAlignment = .center
        distanceToNearBeaconLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(distanceToNearBeaconLabel)

        switchToErrorState()

        apiManager.delegate = self
        apiManager.requestBeaconParametrs()
    }

    private func switchToErrorState() {
        nearBeaconIdLabel.text = "Nearest beacon id: Unknown"
        distanceToNearBeaconLabel.text = "Distance: Unknown"
        nearBeaconIdLabel.textColor = .red
        distanceToNearBeaconLabel.textColor = .red
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func startPositionTracking() {
        locationManager.delegate = self

        if let uuid = UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825") {
            myBeaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "ru.handh.HHLocation.ios")
            if let region = myBeaconRegion {
                region.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: region)
                locationManager.startRangingBeacons(in: region)
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

    func locationManager(_: CLLocationManager, didEnterRegion _: CLRegion) {
        if let region = myBeaconRegion {
            locationManager.startRangingBeacons(in: region)
        } else {
            print("Error: Error start ranging beacons")
            presentAlert(title: "Error", message: "Error start ranging beacons", reloadFunction: nil)
        }
    }

    func locationManager(_: CLLocationManager, didExitRegion _: CLRegion) {
        switchToErrorState()

        if let region = myBeaconRegion {
            locationManager.stopRangingBeacons(in: region)
        } else {
            print("Error: Error stop ranging beacons")
            presentAlert(title: "Error", message: "Error stop ranging beacons", reloadFunction: nil)
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

    // MARK: - Private

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

        if let nearDistance = sortedDistances.first, nearDistance.value < 10.0, nearDistance.key != lastNearestUId {
            showPosition(nearDistance: nearDistance)
        }
    }

    private func showPosition(nearDistance: (key: Int, value: Double)) {
        if let beaconParameters = beaconParameters(uid: nearDistance.key) {
            nearBeaconIdLabel.text = "Nearest beacon id: \(nearDistance.key)"
            distanceToNearBeaconLabel.text = "Distance: \(nearDistance.value)"
            nearBeaconIdLabel.textColor = .lightGray
            distanceToNearBeaconLabel.textColor = .lightGray

            lastNearestUId = beaconParameters.uId
            apiManager.sendLocation(posX: beaconParameters.posX, posY: beaconParameters.posY)
        }
    }

    private func beaconParameters(uid: Int) -> Beacon? {
        return beaconsParameters.first(where: { $0.uId == uid })
    }

    // MARK: - ApiManagerDelegate

    func updateBeaconsParameters(beaconsParameters: [Beacon]) {
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

        present(alert, animated: true, completion: nil)
    }

    private(set) lazy var deviceIdStack: UIStackView = {
        let deviceIdStack = UIStackView()
        deviceIdStack.axis = .vertical
        deviceIdStack.spacing = 15.0

        let deviceIdLabel = UILabel()
        deviceIdLabel.textAlignment = .center
        deviceIdLabel.numberOfLines = 0
        deviceIdLabel.textColor = .white
        deviceIdLabel.text = """
           The device ID is
           \(UIDevice.current.identifierForVendor?.uuidString ?? "NOT AVAILABLE")

           This device may be not registered in the admin panel 🙁.
           In that case, please add this id to the admin panel below.
        """
        deviceIdLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceIdStack.addArrangedSubview(deviceIdLabel)

        let buttonsStack = UIStackView()
        buttonsStack.distribution = .fillEqually
        deviceIdStack.addArrangedSubview(buttonsStack)

        let copyButton = UIButton()
        copyButton.setTitle("👉  Copy", for: .normal)
        copyButton.setTitleColor(.gray, for: .highlighted)
        copyButton.addTarget(self, action: #selector(copyUUID(_:)), for: .touchUpInside)
        buttonsStack.addArrangedSubview(copyButton)

        let openButton = UIButton()
        openButton.setTitle("Open  👈", for: .normal)
        openButton.setTitleColor(.gray, for: .highlighted)
        openButton.addTarget(self, action: #selector(openAdminPanel(_:)), for: .touchUpInside)
        buttonsStack.addArrangedSubview(openButton)

        return deviceIdStack
    }()

    @objc
    private func openAdminPanel(_: UIButton) {
        guard let url = URL(string: "http://d.handh.ru:8887/admin/devices") else {
            return
        }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, completionHandler: nil)
        } else {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.openURL(url)
            }
        }
    }

    @objc
    private func copyUUID(_: UIButton) {
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            UIPasteboard.general.string = uuid
        }
    }
}
