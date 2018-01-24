//
//  ViewController.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/23/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var actionBtn: RoundedShadowButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // set delegate
        mapView.delegate = self

    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {

        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
    }

    



}

