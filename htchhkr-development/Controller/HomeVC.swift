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

    // MARK: - Outlets

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var actionBtn: RoundedShadowButton!

    @IBOutlet weak var centerMapBtn: UIButton!

    @IBOutlet weak var destinationTextField: UITextField!
    
    @IBOutlet weak var destinationCircle: CircleView!

    // MARK: - Properties

//    var currentUserId: String?

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

        // Set up an observer that persistantly monitors the driver's reference in firebase and if something changes, then we're going to run through an update their location
        DataService.instance.REF_DRIVERS.observe(.value) { (snapshot) in
            self.loadDriverAnnotationFromFB()
        }


        // set delegates
        mapView.delegate = self
        destinationTextField.delegate = self




        loadDriverAnnotationFromFB()

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
        centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
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
                print("error: \(String(describing: error))")
            } else if response!.mapItems.count == 0 {
                print("No results from search!")
            } else {
                // if there was at least one result
                for mapItem in response!.mapItems {
                    self.matchingItems.append(mapItem as MKMapItem)
                    // reload view with new data
                    self.tableView.reloadData()
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

    func searchMapKitForResultsWithPolyline(forMapItem mapItem: MKMapItem) {

        let request = MKDirectionsRequest()
        // Source is the user's destination
        request.source = MKMapItem.forCurrentLocation()
        // destination is the mapItem we pass in
        request.destination = mapItem
        request.transportType = MKDirectionsTransportType.automobile

        // pass in this requset into an instance of MKDirectionsRequest
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            guard let response = response else {
                print(error.debugDescription)
                return
            }

            // set route equal to whatever we get back from our respose

            self.route = response.routes[0]

            // add a polyline to display the route on the map
            self.mapView.add(self.route.polyline)
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

        // Drop a pin of selected Address location.
        dropPinFor(placemark: selectedMapItem.placemark)

        searchMapKitForResultsWithPolyline(forMapItem: selectedMapItem)

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
