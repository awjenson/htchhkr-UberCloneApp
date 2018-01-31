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



}
