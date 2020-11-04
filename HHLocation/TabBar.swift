//
//  TabBar.swift
//  HHLocation
//
//  Created by HeadsAndHands on 05.09.2018.
//  Copyright © 2018 HeadsAndHands. All rights reserved.
//

import UIKit

class TabBar: UITabBarController {
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        
        //Map
        let mapViewController = MapViewController()
        mapViewController.apiManager = self.apiManager
        
        let mapItem = UITabBarItem(title: "Map", image: UIImage(named: "ItemMap"), tag: 0)
        mapViewController.tabBarItem = mapItem
        
        //Settings
        let settingsViewController = SettingsViewController()
        settingsViewController.apiManager = self.apiManager
        settingsViewController.locationManager = self.locationManager
        
        let settingsItem = UITabBarItem(title: "Settings", image: UIImage(named: "ItemSettings"), tag: 1)
        settingsViewController.tabBarItem = settingsItem
        
        return [mapViewController, settingsViewController]
    }()
    
    private lazy var apiManager: ApiManager = {
        let manager = ApiManager()
        manager.delegate = self
        
        return manager
    }()
    
    private lazy var locationManager: LocationManager = {
        let manager = LocationManager()
        manager.delegate = self
        
        return manager
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.viewControllers = orderedViewControllers
    }
}

// MARK: ApiManagerDelegate

extension TabBar: ApiManagerDelegate {
    func updateBeaconsParameters(beacons: [Beacon]) {
        locationManager.beaconsParameters = beacons
    }
    
    func switchToErrorState() {
        guard let viewControllers = self.viewControllers else {
            return
        }
        
        for viewController in viewControllers {
            if let vc = viewController as? ParentViewControllerDelegate {
                vc.switchToErrorState()
            }
        }
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
    
    func completeRequest(error: Bool) {
        guard let viewControllers = self.viewControllers else {
            return
        }
        
        for viewController in viewControllers {
            if let vc = viewController as? ParentViewControllerDelegate {
                vc.completeRequest(error: error)
            }
        }
    }
}

// MARK: - LocationManagerDelegate

extension TabBar: LocationManagerDelegate {
    
    func detectedBeacon(beacon: Beacon, distance: Double) {
        apiManager.sendLocation(posX: beacon.posX, posY: beacon.posY)
        
        guard let viewControllers = self.viewControllers else {
            return
        }
        
        for viewController in viewControllers {
            if let vc = viewController as? ParentViewControllerDelegate {
                vc.detectedBeacon(beacon: beacon, distance: distance)
            }
        }
    }
    
    
}

// MARK: - Protocol ApiManagerDelegate

protocol ParentViewControllerDelegate: class {
    func detectedBeacon(beacon: Beacon, distance: Double)
    func switchToErrorState()
    func completeRequest(error: Bool)
}

