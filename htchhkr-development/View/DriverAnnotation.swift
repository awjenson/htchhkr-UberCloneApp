//
//  DriverAnnotation.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 2/2/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import Foundation
import MapKit

// In order to use an MKAnnotation, you need to conform to NSObject
class DriverAnnotation: NSObject, MKAnnotation {

    // dynamic added to get annotation to follow driver icon on mapView. dynamic gives it objective C features
    dynamic var coordinate: CLLocationCoordinate2D
    var key: String

    // create initializer that will be called anytime we create a DriverAnnotation, pass in the properties above
    init(coordinate: CLLocationCoordinate2D, withKey key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }

    func update(annotationPosition annotation: DriverAnnotation, withCoordinate coordinate: CLLocationCoordinate2D) {
        // Every time the coordinates change we can update and animate the moving of the position
        // current coordinates
        var location = self.coordinate
        // new coordinate
        location.latitude = coordinate.latitude
        location.longitude = coordinate.longitude
        UIView.animate(withDuration: 0.2) {
            self.coordinate = location
        }
    }

    

}
