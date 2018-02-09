//
//  DataService.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/30/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import Foundation
import Firebase

// root directory url: https://htchhkr-d0629.firebaseio.com/
let DB_BASE = Database.database().reference()

class DataService {
    static let instance = DataService()

    private var _REF_BASE = DB_BASE
    // Will create a new "folder" titled "users" or if it already exists
    private var _REF_USERS = DB_BASE.child("users")
    private var _REF_DRIVERS = DB_BASE.child("drivers")
    private var _REF_TRIPS = DB_BASE.child("trips")

    // Data encapsulation. We need a way to access the private variables. We're preventing the private variables from being modified directly.
    var REF_BASE: DatabaseReference {
        return _REF_BASE
    }

    var REF_DRIVERS: DatabaseReference {
        return _REF_DRIVERS
    }

    var REF_USERS: DatabaseReference {
        return _REF_USERS
    }

    var REF_TRIPS: DatabaseReference {
        return _REF_TRIPS
    }

    func createFirebaseDBUser(uid: String, userData: Dictionary<String, Any>, isDriver: Bool) {
        if isDriver {
            // We're creating a user that is a driver and creating it with a 'uid'
            REF_DRIVERS.child(uid).updateChildValues(userData)
        } else {
            // if not a driver then they are a user
            REF_USERS.child(uid).updateChildValues(userData)
        }
    }

    func driverIsAvailable(key: String, handler: @escaping (_ status: Bool?) -> Void) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.key == key {
                        if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                            // Check if they are not on a trip
                            if driver.childSnapshot(forPath: "driverIsOnTrip").value as? Bool == true {
                                // Pass things to our handler
                                // They are not available
                                handler(false)
                            } else {
                                handler(true)
                            }
                        }
                    }
                }
            }
        })
    }

    func driverIsOnTrip(driverKey: String, handler: @escaping (_ status: Bool?, _ driverKey: String?, _ tripKey: String?) -> Void) {
        DataService.instance.REF_DRIVERS.child(driverKey).child("driverIsOnTrip").observe(.value, with: { (driverTripStatusSnapshot) in
            if let driverTripStatusSnapshot = driverTripStatusSnapshot.value as? Bool {
                if driverTripStatusSnapshot == true {
                    DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                            // Find the specific trip that the driver is on
                            for trip in tripSnapshot {
                                if trip.childSnapshot(forPath: "driverKey").value as? String == driverKey {
                                    // call handler and pass back some values
                                    handler(true, driverKey, trip.key)
                                } else {
                                    return
                                }
                            }
                        }
                    })
                } else {
                    // if false, were going to set it up to return false for the status and nil for the driverKey and tripKey
                    handler(false, nil, nil)
                }
            }
        })
    }

    func passengerIsOnTrip(passengerKey: String, handler: @escaping (_ status: Bool?, _ driverKey: String?, _ tripKey: String?) -> Void) {
        DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
            if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                // cycle through the array to find the specific trip that the user is on
                for trip in tripSnapshot {
                    if trip.key == passengerKey {
                        if trip.childSnapshot(forPath: "tripIsAccepted").value as? Bool == true {
                            let driverKey = trip.childSnapshot(forPath: "driverKey").value as? String
                            handler(true, driverKey, trip.key)
                        } else {
                            handler(false, nil, nil)
                        }
                    }
                }

            }
        })
    }

    func userIsDriver(userKey: String, handler: @escaping (_ status: Bool) -> Void) {
        DataService.instance._REF_DRIVERS.observeSingleEvent(of: .value, with: { (driverSnapshot) in
            if let driverSnapshot = driverSnapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.key == userKey {
                        handler(true)
                    } else {
                        handler(false)
                    }
                }
            }
        })
    }



}
