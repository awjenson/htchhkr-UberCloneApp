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

class HomeVC: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var actionBtn: RoundedShadowButton!

    var delegate: CenterVCDelegate?

    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // set delegate
        mapView.delegate = self

        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        revealingSplashView.heartAttack = true
    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {

        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
    }

    @IBAction func menuButtonWasPressed(_ sender: UIButton) {
        // call the function from our delegate, toggleLeftPanel. Whenever leftPanel is toggled it is going to open up our containerVC
        delegate?.toggleLeftPanel()
    }
    





}

