//
//  UpdateService.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 2/2/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Firebase

// Singleton
class UpdateService {
    static var instance = UpdateService()

    // functions that allow us to pass a coordinate from our mapview and cycle through all of our users in our firebase database. pass in a new child called coordindate into whatever user account matches our current user.
    func updateUserLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    // check uid of current user
                    if user.key == Auth.auth().currentUser?.uid {
                        // Pass in the coordinates of the current user
                        print("ANDREW: We have found User: \(user.key)")
                        DataService.instance.REF_USERS.child(user.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                    }
                }
            }
        })
    }

    func updateDriverLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.key == Auth.auth().currentUser?.uid {
                        print("ANDREW: We have found Driver: \(driver.key)")
                        // We have found the current driver based on their uid
                        // If the value of the key isPickupModeEnabled is not enabled (false) then we don't need to update their location constantly
                        if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                            DataService.instance.REF_DRIVERS.child(driver.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                        }
                    }
                }
            }

        })
    }

    func observeTrips(handler: @escaping(_ coordinateDict: Dictionary<String, AnyObject>?) -> Void) {
        // setup an observer
        DataService.instance.REF_TRIPS.observe(.value, with: { (snapshot) in
            if let tripSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for trip in tripSnapshot {
                    // verify that it has a passenger key and that it has the property tripIsAccepted
                    if trip.hasChild("passengerKey") && trip.hasChild("tripIsAccepted") {
                        if let tripDict = trip.value as? Dictionary<String, AnyObject> {
                            // call handler
                            handler(tripDict)
                        }
                    }
                }
            }
        })
    }

    func updateTripsWithCoordinatesUponRequest() {
        // Set-up observer on user child. If this function is called, it will take the user's location, trip coordinate
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == Auth.auth().currentUser?.uid {
                        // Make sure we're not using a Driver
                        if !user.hasChild("userIsDriver") {
                            // Crate a dictionary
                            if let userDict = user.value as? Dictionary<String, AnyObject> {
                                let pickUpArray = userDict["coordinate"] as! NSArray

                                // Create a destination array
                                let destinationArray = userDict["tripCoordinate"] as! NSArray

                                // Create a Trip
                                // Pass in the pickup Coordinate
                                DataService.instance.REF_TRIPS.child(user.key).updateChildValues(
                                    ["pickupCoordinate": [pickUpArray[0], pickUpArray[1]],
                                     "destinationCoordinate": [destinationArray[0], destinationArray[1]],
                                     "passengerKey": user.key,
                                     "tripIsAccepted": false])
                            }
                        }
                    }
                }
            }
        })
    }

    func acceptTrip(withPassengerKey passengerKey: String, forDriverKey driverKey: String) {
        DataService.instance.REF_TRIPS.child(passengerKey).updateChildValues(["driverKey": driverKey, "tripIsAccepted": true])
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues(["driverIsOnTrip": true])
    }

    func cancelTrip(withPassengerKey passengerKey: String, forDriverKey driverKey: String?) {
        DataService.instance.REF_TRIPS.child(passengerKey).removeValue()
        DataService.instance.REF_USERS.child(passengerKey).child("tripCoordinate").removeValue()

        if driverKey != nil {
            DataService.instance.REF_DRIVERS.child(driverKey!).updateChildValues(["driverIsOnTrip": false])
        }

    }

}

