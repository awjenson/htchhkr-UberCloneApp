//
//  HomeVCr.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/23/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import MapKit
import RevealingSplashView
import CoreLocation // get user location and connect with MapView

class HomeVC: UIViewController {

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var actionBtn: RoundedShadowButton!

    var delegate: CenterVCDelegate?

    // It can request auth, display user's location
    var manager: CLLocationManager?

    var regionRadius: CLLocationDistance = 1000

    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // order here is important. Instanciate CLLocationManager before we call checkLocationAuthStatus()
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        // Update location after we have granted access
        checkLocationAuthStatus()


        // set delegate
        mapView.delegate = self

        centerMapOnUserLocation()

        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        revealingSplashView.heartAttack = true
    }

    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            // request auth and then set to always auth
            manager?.requestAlwaysAuthorization()
        }
    }

    func centerMapOnUserLocation() {
        print("ANDREW: User Location Coordinate: \(mapView.userLocation.coordinate)")
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        // set region
        mapView.setRegion(coordinateRegion, animated: true)

    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {

        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
    }

    @IBAction func menuButtonWasPressed(_ sender: UIButton) {
        // call the function from our delegate, toggleLeftPanel. Whenever leftPanel is toggled it is going to open up our containerVC
        delegate?.toggleLeftPanel()
    }

    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        centerMapOnUserLocation()
    }


}

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
}

extension HomeVC: MKMapViewDelegate {
    // a func called didUpdateUserLocation to send location of driver/user
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
    }
}
