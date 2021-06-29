//
//  ViewController.swift
//  HHLocation
//
//  Created by HeadsAndHands on 03.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import CoreLocation
import KeyboardManager
import UIKit

final class ViewController: UIViewController {
    let countSignalsForFilter = 5

    var beaconsParameters: [Beacon] = []

    var beaconsSignals: [Int: [Int]] = [:]

    var lastNearestUId: Int = 0

    let nearBeaconIdLabel = UILabel()

    var myBeaconRegion: CLBeaconRegion?
    private(set) lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        return locationManager
    }()

    let apiManager = ApiManager()

    let deviceId = UIDevice.current.identifierForVendor?.uuidString
    let deviceName = UIDevice.current.name
    let keyboardManager: KeyboardManagerProtocol = KeyboardManager(notificationCenter: .default)

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
        stackView.distribution = .equalCentering
        stackView.spacing = 10.0
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 15, left: 15, bottom: 30, right: 15)

        view.addSubview(stackView)
        let bottomConstraint = stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            bottomConstraint,
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor),
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])

        stackView.addArrangedSubview(UIView())
        stackView.addArrangedSubview(deviceIdStack)
        stackView.addArrangedSubview(greetingsLabel)

        stackView.addArrangedSubview({
            let embedStackView = UIStackView()
            embedStackView.axis = .vertical
            embedStackView.spacing = 10.0

            self.nearBeaconIdLabel.textAlignment = .center
            embedStackView.addArrangedSubview(nearBeaconIdLabel)
            embedStackView.addArrangedSubview(deviceNameLabel)
            return embedStackView
        }())

        switchToErrorState()

        apiManager.delegate = self
        apiManager.requestBeaconParameters()

        deviceIdStack.isHidden = true
        greetingsLabel.isHidden = true

        apiManager.allDevices { [unowned self] devices in
            let contains = devices.contains(where: { $0.uid == self.deviceId })
            self.switchToRegisterState(contains)
        }

        keyboardManager.bindToKeyboardNotifications(superview: view, bottomConstraint: bottomConstraint, bottomOffset: 0)
    }

    private func switchToRegisterState(_ isRegister: Bool) {
        deviceIdStack.isHidden = isRegister
        greetingsLabel.isHidden = !isRegister
    }

    private func switchToErrorState() {
        nearBeaconIdLabel.text = "Nearest beacon id: Unknown"
        nearBeaconIdLabel.textColor = .red
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func startPositionTracking() {
        if let uuid = UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825") {
            let beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "ru.handh.HHLocation.ios")
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyEntryStateOnDisplay = true
            locationManager.startMonitoring(for: beaconRegion)
            locationManager.startRangingBeacons(in: beaconRegion)
            myBeaconRegion = beaconRegion
        } else {
            print("Error: Error in the UUID region")
            presentAlert(title: "Error", message: "Error in the UUID region", reloadFunction: nil)
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
            nearBeaconIdLabel.textColor = .lightGray

            lastNearestUId = beaconParameters.uid
            apiManager.sendLocation(posX: beaconParameters.posX, posY: beaconParameters.posY)
        }
    }

    private func beaconParameters(uid: Int) -> Beacon? {
        return beaconsParameters.first(where: { $0.uid == uid })
    }

    private(set) lazy var deviceNameLabel: UILabel = {
        let deviceNameLabel = UILabel()
        deviceNameLabel.textAlignment = .center
        deviceNameLabel.text = "Settings device name: \(self.deviceName)"
        deviceNameLabel.textColor = .lightGray
        deviceNameLabel.numberOfLines = 0
        return deviceNameLabel
    }()

    private(set) lazy var greetingsLabel: UIView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 5.0

        let greetingsLabel = UILabel()
        greetingsLabel.textColor = .white
        greetingsLabel.text = """
        Congratulations, the device is added to the admin panel🌈. Make sure that you:
        """
        greetingsLabel.numberOfLines = 0
        greetingsLabel.textAlignment = .center
        greetingsLabel.font = UIFont.systemFont(ofSize: 22)
        stackView.addArrangedSubview(greetingsLabel)

        let descriptionLabel = UILabel()
        descriptionLabel.textColor = .lightGray
        descriptionLabel.text = """
            - Turn on Bluetooth in settings 
            - Enable location services access in background mode
        """
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = UIFont.systemFont(ofSize: 20)
        stackView.addArrangedSubview(descriptionLabel)

        return stackView
    }()

    private(set) lazy var deviceIdStack: UIStackView = {
        let deviceIdStack = UIStackView()
        deviceIdStack.axis = .vertical
        deviceIdStack.spacing = 15.0

        let deviceIdLabel = UILabel()
        deviceIdLabel.textAlignment = .center
        deviceIdLabel.numberOfLines = 0
        deviceIdLabel.textColor = .white
        deviceIdLabel.text = """
           The device ID should to be added to remote database.
           Please enter device name and tap on the send button.
        """
        deviceIdLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceIdStack.addArrangedSubview(deviceIdLabel)

        deviceIdStack.addArrangedSubview(self.nameTextField)

        let sendButton = UIButton()
        sendButton.setTitle("👉 SEND", for: .normal)
        sendButton.setTitleColor(.lightGray, for: .highlighted)
        sendButton.addTarget(self, action: #selector(send(_:)), for: .touchUpInside)
        deviceIdStack.addArrangedSubview(sendButton)

        return deviceIdStack
    }()

    private(set) lazy var nameTextField: UITextField = {
        let nameTextField = UITextField()
        nameTextField.textAlignment = .center
        nameTextField.textColor = .lightGray
        nameTextField.text = self.deviceName
        nameTextField.delegate = self
        return nameTextField
    }()

    @objc
    private func send(_: UIButton) {
        guard let deviceId = self.deviceId else {
            return
        }
        let device = Device(name: nameTextField.text ?? deviceName, uid: deviceId)
        apiManager.register(device, completion: { success in
            self.switchToRegisterState(success)
            self.nameTextField.resignFirstResponder()
        })
    }
}

extension ViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
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
}

// MARK: - ApiManagerDelegate

extension ViewController: ApiManagerDelegate {
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
}
