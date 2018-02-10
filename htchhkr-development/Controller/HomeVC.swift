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

// Identify what to do based on certain cases we pass in
enum AnnotationType {
    case pickup
    case destination
    case driver
}

enum ButtonAction {
    case requestRide
    case getDirectionsToPassenger
    case getDirectionsToDestination
    case startTrip
    case endTrip
}

class HomeVC: UIViewController, Alertable {

    // MARK: - Outlets

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var actionBtn: RoundedShadowButton!

    @IBOutlet weak var centerMapBtn: UIButton!

    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    
    @IBOutlet weak var destinationCircle: CircleView!

    // MARK: - Properties
    var currentUserId = Auth.auth().currentUser?.uid

    var delegate: CenterVCDelegate?

    // It can request auth, display user's location
    var manager: CLLocationManager?

    var regionRadius: CLLocationDistance = 1000

    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)

    var tableView = UITableView()

    // search results, instantiate
    var matchingItems: [MKMapItem] = [MKMapItem]()

    var route: MKRoute!

    var selectedItemPlacemark: MKPlacemark? = nil

    // set default variable to be requestRide since this is the first option when the user opens up the app
    var actionForButton: ButtonAction = .requestRide

    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        currentUserId = Auth.auth().currentUser?.uid
//        print("ANDREW currentUserId: \(currentUserId!)")

        // order here is important. Instanciate CLLocationManager before we call checkLocationAuthStatus()
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest

        // Update location after we have granted access
        checkLocationAuthStatus()

        // set delegates
        mapView.delegate = self
        destinationTextField.delegate = self

        centerMapOnUserLocation()

        // Set up an observer that persistantly monitors the driver's reference in firebase and if something changes, then we're going to run through an update their location
        DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
            self.loadDriverAnnotationFromFB()

            DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                }
            })
        })

//        loadDriverAnnotationFromFB()

        cancelBtn.alpha = 0.0

        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()


        UpdateService.instance.observeTrips { (tripDict) in
            if let tripDict = tripDict {
                let pickupCoordinateArray = tripDict["pickupCoordinate"] as! NSArray
                let tripKey = tripDict["passengerKey"] as! String
                let acceptanceStatus = tripDict["tripIsAccepted"] as! Bool

                if acceptanceStatus == false {
                    // Check if drivers are avaialble
                    DataService.instance.driverIsAvailable(key: self.currentUserId!, handler: { (available) in
                        if let available = available {
                            // check that value is true
                            if available == true {
                                // instanciate a view controller to display a view controller
                                let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
                                let pickupVC = storyboard.instantiateViewController(withIdentifier: "PickupVC") as? PickupVC

                                // Before we present it, input the data that will display
                                pickupVC?.initData(coordinate: CLLocationCoordinate2DMake(pickupCoordinateArray[0] as! CLLocationDegrees, pickupCoordinateArray[1] as! CLLocationDegrees), passengerKey: tripKey)
                                self.present(pickupVC!, animated: true, completion: nil)
                            }
                        }
                    })
                    
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DataService.instance.userIsDriver(userKey: currentUserId!, handler: { (status) in
            if status == true {
                self.buttonsForDriver(areHidden: true)
            }
        })

        DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {

                // driver is on a trip
                DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                        for trip in tripSnapshot {
                            if trip.childSnapshot(forPath: "driverKey").value as? String == self.currentUserId! {
                                // Create an array that has the value of key "pickupCoordinate" and cast as a NSArray.
                                let pickupCoordinateArray = trip.childSnapshot(forPath: "pickupCoordinate").value as! NSArray

                                // in order to display a pin on a mapview we need to create a placemark
                                let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                // With this placemark we can now drip a pin of our location and generate a route on the mapview from where the driver is to the passenger
                                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)

                                self.dropPinFor(placemark: pickupPlacemark)
                                // create a MKMapItem within function
                                self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))

                                self.setCustomRegion(forAnnotationType: .pickup, withCoordinate: pickupCoordinate)

                                self.actionForButton = .getDirectionsToPassenger
                                self.actionBtn.setTitle("GET DIRECTIONS", for: .normal)

                                // Fade in the action button for the driver
                                self.buttonsForDriver(areHidden: false)
                            }
                        }
                    }
                })
            }
        })

        // this will only work for a passenger who is on a trip that is accepted. If a passenger is not on a trip that it does matter b/c it will only work on users that are on an accepted trip. Otherwise, it will be ignored.
        connnectUserAndDriverForTrip()
    }

    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            // request auth and then set to always auth
            manager?.requestAlwaysAuthorization()
        }
    }

    func buttonsForDriver(areHidden: Bool) {
        if areHidden {
            self.actionBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.actionBtn.isHidden = true
            self.cancelBtn.isHidden = true
            self.centerMapBtn.isHidden = true
        } else {
            // if false
            self.actionBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.actionBtn.isHidden = true
            self.cancelBtn.isHidden = true
            self.centerMapBtn.isHidden = true
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

        // After all of the annotations have been added to the mapView, hide
        revealingSplashView.heartAttack = true
    }


    func connnectUserAndDriverForTrip() {

        DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {

                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)

                DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                    let driverId = tripDict?["driverKey"] as! String

                    let pickupCoordinateArray = tripDict?["pickupCoordinate"] as! NSArray
                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                    let pickupMapItem = MKMapItem(placemark: pickupPlacemark)

                    DataService.instance.REF_DRIVERS.child(driverId).child("coordinate").observeSingleEvent(of: .value, with: { (coordinateSnapshot) in

                        let coordinateSnapshot = coordinateSnapshot.value as! NSArray
                        let driverCoordinate =  CLLocationCoordinate2D(latitude: coordinateSnapshot[0] as! CLLocationDegrees, longitude: coordinateSnapshot[1] as! CLLocationDegrees)
                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)

                        self.mapView.addAnnotation(passengerAnnotation)
                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)

                        self.actionBtn.animateButton(shouldLoad: false, withMessage: "DRIVER COMING")
                        self.actionBtn.isUserInteractionEnabled = false
                    })

                    DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        if tripDict?["tripIsInProgress"] as? Bool == true {
                            self.removeOverlaysAndAnnotations(forDrivers: true, forPassengers: true)

                            let destinationCoordinateArray = tripDict?["destinationCoordinate"] as! NSArray
                            let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)

                            self.dropPinFor(placemark: destinationPlacemark)
                            self.searchMapKitForResultsWithPolyline(forOriginMapItem: pickupMapItem, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))

                            self.actionBtn.setTitle("ON TRIP", for: .normal)
                        }
                    })
                })
            }
        })
    }


    func centerMapOnUserLocation() {
        print("ANDREW: User Location Coordinate: \(mapView.userLocation.coordinate)")
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        // set region
        mapView.setRegion(coordinateRegion, animated: true)

    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {
        buttonSelector(forAction: actionForButton)
    }

    @IBAction func cancelBtnWasTapped(_ sender: Any) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            // inside closure, check if isOnTrip is true
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
            }
        }

        // Check if passenger is on trip. Pass in the passengerKey and return all of the values from inside this Firebase child.
        DataService.instance.passengerIsOnTrip(passengerKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                // if on a trip, cancel trip
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: driverKey!)
            } else {
                // if not on a trip, cancel trip
                // no 'forDriverKey' so pass in nil
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: nil)
            }
        }

        // renable UI
        self.actionBtn.isUserInteractionEnabled = true
        
    }


    @IBAction func menuButtonWasPressed(_ sender: UIButton) {
        // call the function from our delegate, toggleLeftPanel. Whenever leftPanel is toggled it is going to open up our containerVC
        delegate?.toggleLeftPanel()
    }

    @IBAction func centerMapBtnWasPressed(_ sender: Any) {

        DataService.instance.REF_USERS.child(currentUserId!).observeSingleEvent(of: .value, with: { (snapshot) in
            for child in snapshot.children {
                print(child)
            }
            if snapshot.hasChild("tripCoordinate") {
                self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
            } else {
                self.centerMapOnUserLocation()
            }
            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
        })

        centerMapOnUserLocation()
        centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }

    // The enum we created, ButtonAction
    func buttonSelector(forAction action: ButtonAction) {
        switch action {
        case .requestRide:
            if destinationTextField.text != "" {
                UpdateService.instance.updateTripsWithCoordinatesUponRequest()
                actionBtn.animateButton(shouldLoad: true, withMessage: nil)
                cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)

                self.view.endEditing(true)
                destinationTextField.isUserInteractionEnabled = false
            }

        case .getDirectionsToPassenger:
            // see if the driver is on a trip
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                // observe trip reference
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).observe(.value, with: { (tripSnapshot) in
                        let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>

                        // create an array and cast into CLLocation
                        let pickupCoordinateyArray = tripDict?["pickupCoordinate"] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateyArray[0] as! CLLocationDegrees, longitude: pickupCoordinateyArray[1] as! CLLocationDegrees)

                        // This mapItem will be passed over to the iOS map's app.
                        let pickupMapItem = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate))
                        pickupMapItem.name = "Passenger Pickup Point"
                        pickupMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .startTrip:
            print("start trip")
            // First we need to verify if the driver is on a trip, because if they are not then they shouldn't be able to start a trip.
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: false)
                    // But we do want to remove the overlay (the orange route line) because we want to remove, from the driver screen, when the driver goes to pickup the passenger, the passenger shows up as a red pin. The red pin are of type MKPointAnnotation

                    // pass in a new boolean and use it for trips
                    DataService.instance.REF_TRIPS.child(tripKey!).updateChildValues(["tripIsInProgress": true])

                    DataService.instance.REF_TRIPS.child(tripKey!).child("destinationCoordinate").observeSingleEvent(of: .value, with: { (coordinateSnapshot) in

                        // Create a destinationCoordinateArray, destinationCoordiate, and destinationPlacemark
                        let destinationCoordinateArray = coordinateSnapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)

                        self.dropPinFor(placemark: destinationPlacemark)
                        // show a new route polyline, create a MKMapItem
                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))

                        self.setCustomRegion(forAnnotationType: .destination, withCoordinate: destinationCoordinate)
                        self.actionForButton = .getDirectionsToDestination
                        self.actionBtn.setTitle("GET DIRECTIONS", for: .normal)
                    })
                }
            })
        case .getDirectionsToDestination:
            print("get directions")
        case .endTrip:
            print("end trip")
        }
    }

}

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip == true {
                if region.identifier == "pickup" {
                    self.actionForButton = .startTrip
                    // Change action button to have a new title
                    self.actionBtn.setTitle("START TRIP", for: .normal)
                    print("Driver entered pickup region!")
                } else if region.identifier == "destination" {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.cancelBtn.isHidden = true
                    self.actionBtn.setTitle("END TRIP", for: .normal)
                }
            }
        })
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                if region.identifier == "pickup" {
                    // call an action on the button that will load directions to passenger pickup
                    print("Driver entered pickup region!")
                    self.actionBtn.setTitle("GET DIRECTIONS", for: .normal)
                } else if region.identifier == "destination" {
                    // call an action on the button that will load directions to destination
                    self.actionBtn.setTitle("GET DIRECTIONS", for: .normal)
                }
            }
        })
    }

}

extension HomeVC: MKMapViewDelegate {
    // a func called didUpdateUserLocation to send location of driver/user
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)

        // First verify if the user is a driver and if they are on a trip
        DataService.instance.userIsDriver(userKey: currentUserId!) { (isDriver) in
            if isDriver == true {
                // Check if they are on a trip
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            } else {
                // check if a passenger is on a trip
                DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            }
        }


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
        } else if let annotation = annotation as? PassengerAnnotation {
            let identifier = "passenger"
            // create a view
            var view: MKAnnotationView
            // instanciate a MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            // Set the image property of the view
            view.image = UIImage(named: "currentLocationAnnotation")
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                // If annotationView is nil then we will set the annotation
                // instanciate it to equal MKAnnoationView with the proper annotation
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                // If it is not nil, then we are going to set it equal to the specific annotation passed in from the mapView (from the 'annotation' property defined in this method.
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: "destinationAnnotation")
            return annotationView
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }

    // Display (render) polyline line from user location to destination. This function is only called after we make a request.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRederer = MKPolylineRenderer(overlay: self.route.polyline)
        lineRederer.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRederer.lineWidth = 3.0

        // Whenever the map creates an overlay, dismiss loading view if it is there
        shouoldPresentLoadingView(false)

        return lineRederer
    }

    func performSearch() {
        // Begin by removing any items that may be in matchingItems (clear out previous search results each time we start a new search)
        matchingItems.removeAll()

        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = destinationTextField.text

        // Set the region to an associated map view's region (what are the bounds of the search, which is the region displayed on the screen and then expand outward beyond the view of the mapView)
        request.region = mapView.region

        let search = MKLocalSearch(request: request)

        // Begin the search process, call the function start
        // 'response' are the search results
        search.start { (response, error) in
            // Check if there is an error, if there is an error
            if error != nil {
                self.showAlert("error: \(String(describing: error))")

            } else if response!.mapItems.count == 0 {
                self.showAlert("No results. Please search again for a different location.")
            } else {
                // if there was at least one result
                for mapItem in response!.mapItems {
                    self.matchingItems.append(mapItem as MKMapItem)
                    // reload view with new data
                    self.tableView.reloadData()
                    // remove the subview with the spinner
                    self.shouoldPresentLoadingView(false)
                }
            }
        }
    }

    func dropPinFor(placemark: MKPlacemark) {
        // From our search results, we select an item from our tableView, the plaecemark that we get from the item we select will be passed into this function. We're going to get an annotation, but this time we don't care it it is a driver or user, so we're going to make it a generic b/c it's for a location from the search results.
        selectedItemPlacemark = placemark

        // Every time we search, we should remove the all of the destination pins before we add new pins on the mapView. So check if an annotation is already on the mapView before we drop a new annotation.
        // Add the check first, before adding a new pin annotation.
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }

        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }

    func searchMapKitForResultsWithPolyline(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {

        let request = MKDirectionsRequest()

        if originMapItem == nil {
            // Source is the user's destination
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }


        // destination is the mapItem we pass in
        request.destination = destinationMapItem
        request.transportType = MKDirectionsTransportType.automobile
        request.requestsAlternateRoutes = true

        // pass in this requset into an instance of MKDirectionsRequest
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert("An error occured, please try again.")
                print(error!)
                return
            }

            // set route equal to whatever we get back from our respose

            self.route = response.routes[0]

            // add a polyline to display the route on the map
            self.mapView.add(self.route.polyline)

            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)

            // create a constant equal to our AppDelegate
            let delegate = AppDelegate.getAppDelegate()

            // Go into the delegate, access the window and then on the window we can get to the root view controller. As soon as we have the root view controller, we can set it to false to hide it.
            delegate.window?.rootViewController?.shouoldPresentLoadingView(false)

        }
    }

    func zoom(toFitAnnotationsFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        // We will call this when we do our search and create our polyline.
        // Check first if there are any annotations

        if mapView.annotations.count == 0 {
            return
        }

        // Setup map to only pay attention to what's inside the screen.
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)

        if forActiveTripWithDriver {
            // search through all annotations in the mapview and
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        // This will create the perfect rectangle that contains both the user location and destination inside the rectangle.
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    // This will create the perfect rectangle that contains both the user location and destination inside the rectangle.
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                }
            }
        }

        // Cycle through all annotations.
        // Right now, just focus on viewing in mapView the user and destination annotations, ignore the driver annoations.
        // For every annotation that is not a DriverAnnoation. Only annotations left are Passenger and Destination.
        for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            // look through all of them except for the ones that are of type driver annoation

            // This will create the perfect rectangle that contains both the user location and destination inside the rectangle.
            topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
            bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
        }

        // Both coordinates are really just averaging the latitude/longitude of the two locations.
//         var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake((topLeftCoordinate.latitude + bottomRightCoordinate.latitude) * 0.5, (topLeftCoordinate.longitude + bottomRightCoordinate.longitude) * 0.5), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))

        var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5),
                                         span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))


        // Set the region to the mapView
        region = mapView.regionThatFits(region)
        mapView.setRegion(region, animated: true)
    }

    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        // cycle through all annoations in the map and check to see if they are of type passenger, driver, or placemark annoation.
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }

            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    mapView.removeAnnotation(annotation)

                }
            }

            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }

        // outside the for loop, search for overlays
        for overlay in mapView.overlays {
            if (overlay is MKPolyline) {
                mapView.remove(overlay)
            }
        }
    }

    func setCustomRegion(forAnnotationType type: AnnotationType, withCoordinate coordinate: CLLocationCoordinate2D) {

        if type == .pickup {
            // create a circle and have our mapView monitor this region
            let pickupRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "pickup")
            manager?.startMonitoring(for: pickupRegion)

        } else if type == .destination {
            let destinationRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "destination")
            manager?.startMonitoring(for: destinationRegion)
        }
    }
}

extension HomeVC: UITextFieldDelegate {
    // 4 functions

    func textFieldDidBeginEditing(_ textField: UITextField) {

        if textField == destinationTextField {

            // setup tableView
            tableView.frame = CGRect(x: 20.0, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")

            tableView.delegate = self
            tableView.dataSource = self

            // give it a tag so we can specifically remove that subview
            tableView.tag = 18
            tableView.rowHeight = 60

            view.addSubview(tableView)
            animateTableView(shouldShow: true)

            UIView.animate(withDuration: 0.2, animations: {
                self.destinationCircle.backgroundColor = UIColor.red
                self.destinationCircle.boardColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
            })
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
             performSearch()
            // we created 'shouldPresentLoadingView in an extension file
            shouoldPresentLoadingView(true)
            view.endEditing(true)
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2, animations: {
                    self.destinationCircle.backgroundColor = UIColor.lightGray
                    self.destinationCircle.boardColor = UIColor.darkGray
                })
            }
        }
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()
        centerMapOnUserLocation()

        // remove all mapKit overlays and annoations from UI and Firebase Database

        // First, Firebase Database
        DataService.instance.REF_USERS.child(currentUserId!).child("tripCoordinate").removeValue()

        // Second, UI
        mapView.removeOverlays(mapView.overlays)

        for annotation in mapView.annotations {

            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            } else if annotation.isKind(of: PassengerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }

        }

        return true
    }

    // Non delegate function (created by us)

    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 20.0, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                // Animate it down to its original frame
                self.tableView.frame = CGRect(x: 20.0, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }, completion: { (finished) in
                for subview in self.view.subviews {
                    if subview.tag == 18 {
                        subview.removeFromSuperview()
                    }
                }
            })
        }
    }
}

extension HomeVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")

        let mapItem = matchingItems[indexPath.row]

        // every mapItem by default has a name
        cell.textLabel?.text = mapItem.name
        // title property of placemark is the Address of the location
        cell.detailTextLabel?.text = mapItem.placemark.title

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        shouoldPresentLoadingView(true)

        // Whenever we select a search result, we should display a pin for the passenger and where they are going
        let passengerCoordinate = manager?.location?.coordinate

        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate!, key: (Auth.auth().currentUser?.uid)!)
        // Add annotation to the mapView
        mapView.addAnnotation(passengerAnnotation)

        // Set the destination textField to display the text of the text Label from the selected row.
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text

        // selectedMapItem is of type MKMapItem
        let selectedMapItem = matchingItems[indexPath.row]

        // any time we select a map item, it will post a new child called "tripCoordinate" and then save it to Firebase for every user that selects a result.
        DataService.instance.REF_USERS.child((Auth.auth().currentUser?.uid)!).updateChildValues(["tripCoordinate": [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])

        print("ANDREW: User Location Coordinate: \(mapView.userLocation.coordinate)")

        print("ANDREW: tripCoordinate: lat \(selectedMapItem.placemark.coordinate.latitude), long \(selectedMapItem.placemark.coordinate.longitude)")

        // Drop a pin of selected Address location.
        dropPinFor(placemark: selectedMapItem.placemark)

        searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: selectedMapItem)

        animateTableView(shouldShow: false)
        print("Selected Row")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
    }
}
