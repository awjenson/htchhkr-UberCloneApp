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
import Firebase

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

        // Set up an observer that persistantly monitors the driver's reference in firebase and if something changes, then we're going to run through an update their location
        DataService.instance.REF_DRIVERS.observe(.value) { (snapshot) in
            self.loadDriverAnnotationFromFB()
        }


        // set delegate
        mapView.delegate = self

        centerMapOnUserLocation()

        loadDriverAnnotationFromFB()

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

    func loadDriverAnnotationFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild("userIsDriver") {

                        // if a driver key has a value "coordinate", then check if "isPickupModeEnabled" set to true. If yes, then pull down the coordinate array and it pull out as an NSArray.  Now, we can bulid a coordinate (with Lat and Long).
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                                if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                    let coordinateArray = driverDict["coordinate"] as! NSArray
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)

                                    // Create an annotation
                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)

                                    var driverIsVisible: Bool {
                                        // search the mapView, look at all the annotations, and see if 'annotation' contains a certain condition and we'll return the condition as true/false
                                        return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                            // Check if current driver annotation matches the current driver key
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                // every driver annotation has a key, if it is equal to the current driver key
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)

                                                    return true
                                                }
                                            }
                                            // case where it doesn't
                                            return false
                                        })
                                    }

                                    // if driver is not visible, we add them
                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                // Search through all of the annotations and remove any driver annotations that match our key
                                for annotation in self.mapView.annotations {
                                    if let annotation = annotation as? DriverAnnotation {
                                        if annotation.key == driver.key {
                                            self.mapView.removeAnnotation(annotation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
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

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            // we're going to use this identifier to properly replace images that are of type driver.
            let identifier = "driver"

            // create a replacement of the typical pin icon
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")
            return view
        }
        return nil
    }
}
