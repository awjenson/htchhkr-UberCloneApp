//
//  PickupVC.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 2/6/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class PickupVC: UIViewController {

    @IBOutlet weak var pickupMapView: RoundMapView!

    var regionRadius: CLLocationDistance = 2000
    var pin: MKPlacemark? = nil
    var pickupCoordinate: CLLocationCoordinate2D!
    var passengerKey: String!
    var locationPlacemark: MKPlacemark!
    var currentUserId = Auth.auth().currentUser?.uid

    override func viewDidLoad() {
        super.viewDidLoad()

        // display map on VC
        pickupMapView.delegate = self
        // drop a pin and zoom in on the map
        locationPlacemark = MKPlacemark(coordinate: pickupCoordinate)
        dropPinFor(placemark: locationPlacemark)
        centerMapOnLocation(location: locationPlacemark.location!)

        DataService.instance.REF_TRIPS.child(passengerKey).observe(.value, with: { (tripSnapshot) in
            // Were only getting one trip snapshot
            // Check first if it exists
            if tripSnapshot.exists() {
                // Check for acceptance
                if tripSnapshot.childSnapshot(forPath: "tripIsAccepted").value as? Bool == true {
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        })
    }


    // We have an initializer function that we can call to pass in data to our mapView methods before we even are available to use it.
    func initData(coordinate: CLLocationCoordinate2D, passengerKey: String) {
        // instanciate them
        self.pickupCoordinate = coordinate
        self.passengerKey = passengerKey
    }

    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func acceptTripBtnWasPressed(_ sender: Any) {
        UpdateService.instance.acceptTrip(withPassengerKey: passengerKey, forDriverKey: currentUserId!)
        presentingViewController?.shouoldPresentLoadingView(true)
    }

}

extension PickupVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // setup how our annotation will look
        let identifier = "pickupPoint"
        var annoationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        if annoationView == nil {
            // create a MKAnnotationView with our identifier
            annoationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annoationView?.annotation = annotation
        }
        annoationView?.image = UIImage(named: "destinationAnnotation")
        return annoationView
    }

    func centerMapOnLocation(location: CLLocation) {
        // find the location of the pin and zoom in.
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius, regionRadius)

        pickupMapView.setRegion(coordinateRegion, animated: true)
    }

    func dropPinFor(placemark: MKPlacemark) {
        pin = placemark

        for annotation in pickupMapView.annotations {
            pickupMapView.removeAnnotation(annotation)
        }

        // setup
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        pickupMapView.addAnnotation(annotation)
    }
}
