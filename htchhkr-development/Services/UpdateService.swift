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
}

