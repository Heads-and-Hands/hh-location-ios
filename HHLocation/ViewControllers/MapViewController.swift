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
    
    var apiManager: ApiManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        
        topInfoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topInfoView)
        topInfoView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        topInfoView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        topInfoView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        topInfoView.heightAnchor.constraint(equalToConstant: 130.0).isActive = true
        
        view.addSubview(mapImageView)
        mapImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        mapImageView.topAnchor.constraint(equalTo: topInfoView.bottomAnchor).isActive = true
    }
}

// MARK: - Private metods

extension MapViewController {
    private func updateUserPosition(coordinate: CGPoint) {
        let newCoordinate = CGPoint(x: mapImageView.bounds.width/mapImageWidth*coordinate.x,
                                    y: mapImageView.bounds.height/mapImageHeight*coordinate.y)
        
        userPin.center = newCoordinate
        mapImageView.addSubview(userPin)
    }
}

// MARK: - ParentViewControllerDelegate

extension MapViewController: ParentViewControllerDelegate {
    
    func detectedBeacon(beacon: Beacon, distance: Double) {
        let coordinate = CGPoint(x: beacon.posX, y: beacon.posY)
        topInfoView.setCoordinate(coordinate: coordinate)
        updateUserPosition(coordinate: coordinate)
    }
    
    func switchToErrorState() {
        topInfoView.setCoordinate(coordinate: nil)
        userPin.removeFromSuperview()
    }
    
    func completeRequest(error: Bool) {
        if error {
            topInfoView.indicatorView.backgroundColor = UIColor.red
        } else {
            topInfoView.indicatorView.backgroundColor = UIColor.green
        }
    }
}

