//
//  PassengerAnnotation.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 2/3/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import Foundation
import MapKit

class PassengerAnnotation: NSObject, MKAnnotation {

    // set up the different properties for our annotation (key and coordinate). for whatever reason you need to set the coordinate to be a dynamic var.
    dynamic var coordinate: CLLocationCoordinate2D
    var key: String

    init(coordinate: CLLocationCoordinate2D, key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
}
