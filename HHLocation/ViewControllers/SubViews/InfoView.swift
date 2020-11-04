//
//  InfoView.swift
//  HHLocation
//
//  Created by HeadsAndHands on 04.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import UIKit


class InfoView: UIView {
    let requestButtonSize: CGFloat = 60.0
    let coordinateLabel = UILabel()
    lazy var requestButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = requestButtonSize/2.0
        button.setTitle("send coord", for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.backgroundColor = UIColor.yellow
        
        return button
    }()
    
    init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor.white
        
        let deviceIdLabel = UILabel()
        deviceIdLabel.numberOfLines = 0
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            deviceIdLabel.text = "Devise ID: \(id)"
        } else {
            deviceIdLabel.text = "Devise ID: Undefined"
        }
        deviceIdLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(deviceIdLabel)
        
        deviceIdLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10.0).isActive = true
        deviceIdLabel.topAnchor.constraint(equalTo: topAnchor, constant: 30.0).isActive = true
        deviceIdLabel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0, constant: -(requestButtonSize + 20)).isActive = true
        
        coordinateLabel.text = "Coordinate: Undefined"
        coordinateLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coordinateLabel)
        
        coordinateLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10.0).isActive = true
        coordinateLabel.topAnchor.constraint(equalTo: deviceIdLabel.bottomAnchor, constant: 10.0).isActive = true
        coordinateLabel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0, constant: -10).isActive = true
        
        requestButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(requestButton)
        
        requestButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -10.0).isActive = true
        requestButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        requestButton.widthAnchor.constraint(equalToConstant: requestButtonSize).isActive = true
        requestButton.heightAnchor.constraint(equalToConstant: requestButtonSize).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public metods
    
    func setCoordinate(coordinate: CGPoint?) {
        if let coord = coordinate {
            coordinateLabel.text = "Coordinate: \(coord.x) --- \(coord.y)"
        } else {
            coordinateLabel.text = "Coordinate: Undefined"
        }
    }
}
