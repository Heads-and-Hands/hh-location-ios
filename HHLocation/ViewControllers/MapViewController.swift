//
//  MapViewController.swift
//  HHLocation
//
//  Created by HeadsAndHands on 04.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import UIKit

class MapViewController: UIViewController {
    
    let mapImageWidth: CGFloat = 700.0
    let mapImageHeight: CGFloat = 450.0
    
    let topInfoView = InfoView()
    
    var position: CGPoint?
    
    let locatingButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 5
        button.addTarget(self, action: #selector(pressLocatingButton(sender:)), for: .touchUpInside)
        
        if (UserDefaults.standard.bool(forKey: "locationDisable")) {
            button.setTitle("Offline mode", for: .normal)
            button.backgroundColor = UIColor.red
        } else {
            button.setTitle("Locating", for: .normal)
            button.backgroundColor = UIColor.green
        }
        
        return button
    }()
    
    let mapImageView: UIImageView = {
        
        let image = UIImage(named: "MapImage")
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        if let img = image {
            let ratio = img.size.width / img.size.height
            let width = UIScreen.main.bounds.width
            let height = width / ratio
            
            imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        
        return imageView
    }()
    
    let userPin: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.red
        view.frame = CGRect(x: 0.0, y: 0.0, width: 10.0, height: 10.0)
        view.layer.cornerRadius = 5.0
        
        return view
    }()
    
    var apiManager: ApiManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        
        topInfoView.requestButton.addTarget(self, action: #selector(pressRequestButton(sender:)), for: .touchUpInside)
        topInfoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topInfoView)
        topInfoView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        topInfoView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        topInfoView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        topInfoView.heightAnchor.constraint(equalToConstant: 130.0).isActive = true
        
        view.addSubview(mapImageView)
        mapImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        mapImageView.topAnchor.constraint(equalTo: topInfoView.bottomAnchor).isActive = true
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(clickImageMap(sender:)))
        mapImageView.addGestureRecognizer(tapRecognizer)
        mapImageView.isUserInteractionEnabled = true
        
        userPin.center = CGPoint(x: UIScreen.main.bounds.width*2, y: 0)
        mapImageView.addSubview(userPin)
        
        locatingButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(locatingButton)
        locatingButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 10.0).isActive = true
        locatingButton.topAnchor.constraint(equalTo: mapImageView.bottomAnchor, constant: 10.0).isActive = true
        locatingButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10.0).isActive = true
        locatingButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
    }
    
    @objc
    func pressLocatingButton(sender: UIButton) {
        let locationDisable = !UserDefaults.standard.bool(forKey: "locationDisable")
        
        if locationDisable {
            locatingButton.setTitle("Offline mode", for: .normal)
            locatingButton.backgroundColor = UIColor.red
        } else {
            locatingButton.setTitle("Locating", for: .normal)
            locatingButton.backgroundColor = UIColor.green
        }
        
        UserDefaults.standard.set(locationDisable, forKey: "locationDisable")
    }
    
    @objc
    func pressRequestButton(sender: UIButton) {
        if let coordinate = position {
            topInfoView.requestButton.backgroundColor = UIColor.blue
            apiManager?.sendLocation(posX: Double(coordinate.x), posY: Double(coordinate.y))
        }
    }
    
    @objc
    func clickImageMap(sender: UITapGestureRecognizer) {
        if sender.state == .ended, UserDefaults.standard.bool(forKey: "locationDisable") {
            let touchLocation = sender.location(in: mapImageView)
            
            let coordinate = CGPoint(x: mapImageWidth/mapImageView.bounds.width*touchLocation.x,
                                        y: mapImageHeight/mapImageView.bounds.height*touchLocation.y)
            
            updateUserPosition(coordinate: coordinate)
            topInfoView.requestButton.backgroundColor = UIColor.gray
        }
    }
}

// MARK: - Private metods

extension MapViewController {
    private func updateUserPosition(coordinate: CGPoint) {
        let newCoordinate = CGPoint(x: mapImageView.bounds.width/mapImageWidth*coordinate.x,
                                    y: mapImageView.bounds.height/mapImageHeight*coordinate.y)
        
        userPin.center = newCoordinate
        position = newCoordinate
        topInfoView.setCoordinate(coordinate: coordinate)
    }
}

// MARK: - ParentViewControllerDelegate

extension MapViewController: ParentViewControllerDelegate {
    
    func detectedBeacon(beacon: Beacon, distance: Double) {
        let coordinate = CGPoint(x: beacon.posX, y: beacon.posY)
        updateUserPosition(coordinate: coordinate)
    }
    
    func switchToErrorState() {
        topInfoView.setCoordinate(coordinate: nil)
        userPin.removeFromSuperview()
    }
    
    func completeRequest(error: Bool) {
        if error {
            topInfoView.requestButton.backgroundColor = UIColor.red
        } else {
            topInfoView.requestButton.backgroundColor = UIColor.green
        }
        topInfoView.requestButton.isEnabled = true
    }
}

