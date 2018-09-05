//
//  SettingsViewController.swift
//  HHLocation
//
//  Created by HeadsAndHands on 05.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import KeyboardManager
import UIKit

class SettingsViewController: UIViewController {

    let nearBeaconIdLabel = UILabel()

    var apiManager: ApiManager?
    
    let keyboardManager: KeyboardManagerProtocol = KeyboardManager(notificationCenter: .default)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
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
        
        deviceIdStack.isHidden = true
        greetingsLabel.isHidden = true
        
        if let manager = apiManager {
            manager.allDevices { [unowned self] devices in
                let contains = devices.contains(where: { $0.uid == manager.deviceId })
                self.switchToRegisterState(contains)
            }
            
        }
        
        keyboardManager.bindToKeyboardNotifications(superview: view, bottomConstraint: bottomConstraint, bottomOffset: 0)
    }
    
    private func switchToRegisterState(_ isRegister: Bool) {
        deviceIdStack.isHidden = isRegister
        greetingsLabel.isHidden = !isRegister
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private(set) lazy var deviceNameLabel: UILabel = {
        let deviceNameLabel = UILabel()
        deviceNameLabel.textAlignment = .center
        deviceNameLabel.text = "Settings device name: \(self.apiManager?.deviceName ?? "Undefined")"
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
        nameTextField.text = self.apiManager?.deviceName
        nameTextField.delegate = self
        return nameTextField
    }()
    
    @objc
    private func send(_: UIButton) {
        guard let deviceId = self.apiManager?.deviceId else {
            return
        }
        let device = Device(name: nameTextField.text ?? apiManager?.deviceName ?? "Undefined", uid: deviceId)
        apiManager?.register(device, completion: { success in
            self.switchToRegisterState(success)
            self.nameTextField.resignFirstResponder()
        })
    }
}

// MARK: - ParentViewControllerDelegate

extension SettingsViewController: ParentViewControllerDelegate {
    func completeRequest(error: Bool) {
    }
    
    func detectedBeacon(beacon: Beacon, distance: Double) {
        nearBeaconIdLabel.text = "Nearest beacon id: \(beacon.uid)"
        nearBeaconIdLabel.textColor = .lightGray
    }
    
    func switchToErrorState() {
        nearBeaconIdLabel.text = "Nearest beacon id: Unknown"
        nearBeaconIdLabel.textColor = .red
    }
}

// MARK: - UITextFieldDelegate

extension SettingsViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
