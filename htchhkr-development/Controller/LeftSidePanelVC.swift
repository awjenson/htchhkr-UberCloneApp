//
//  LeftSidePanelVC.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/24/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import Firebase

class LeftSidePanelVC: UIViewController {

    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLbl: UILabel!
    @IBOutlet weak var userImageView: RoundImageView!

    @IBOutlet weak var userEmailLbl: UILabel!
    @IBOutlet weak var userAccountTypeLbl: UILabel!
    @IBOutlet weak var loginOutBtn: UIButton!

    let appDelegate = AppDelegate.getAppDelegate()
    let currentUserId = Auth.auth().currentUser?.uid

    override func viewDidLoad() {
        super.viewDidLoad()


    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        // When a driver opens the app, they are not automactically in driver mode
        pickupModeSwitch.isOn = false
        pickupModeSwitch.isHidden = true
        pickupModeLbl.isHidden = true

        observePassengersAndDrivers()

        // Let's say there is no user (user is not logged in), what should they see? Only the signup button
        if Auth.auth().currentUser == nil {
            userEmailLbl.text = ""
            userAccountTypeLbl.text = ""
            userImageView.isHidden = true
            loginOutBtn.setTitle("Sign Up / Login", for: .normal)
        } else {
            // If there is a user
            userEmailLbl.text = Auth.auth().currentUser?.email
            userAccountTypeLbl.text = ""
            userImageView.isHidden = false
            loginOutBtn.setTitle("Logout", for: .normal)


        }

    }

    func observePassengersAndDrivers() {
        // Passengers
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            // create an array of individual snapshots and in order to use it we need to cast it as an array of DataSnapshot
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {

                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "PASSENGER"
                    }
                }
            }
        })

        // Drivers
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                // Search through all of the drivers to see if the uid matches an existing driver's uid.
                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "DRIVER"
                        // show it
                        self.pickupModeSwitch.isHidden = false

                        let switchStatus = snap.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool
                        self.pickupModeSwitch.isOn = switchStatus
                        self.pickupModeLbl.isHidden = false
                    }
                }
            }
        })
    }


    @IBAction func switchWasToggled(_ sender: Any) {

        if pickupModeSwitch.isOn {
            pickupModeLbl.text = "PICKUP MODE ENABLED"
            appDelegate.MenuContainerVC.toggleLeftPanel()
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": true])

        } else {
            pickupModeLbl.text = "PICKUP MODE DISABLED"
            appDelegate.MenuContainerVC.toggleLeftPanel()
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": false])
        }
    }


    @IBAction func signUpLoginBtnWasPressed(_ sender: UIButton) {

        // When there is a user, it will show signOut and the func will be different. If there is no user, it will show SignIn and the func will be the way it is now.
        if Auth.auth().currentUser == nil {

            // create instance of storyboard
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as? LoginVC
            present(loginVC!, animated: true, completion: nil)
        } else {
            do {
                try Auth.auth().signOut()
                userEmailLbl.text = ""
                userAccountTypeLbl.text = ""
                userImageView.isHidden = true
                pickupModeLbl.text = ""
                pickupModeSwitch.isHidden = true
                loginOutBtn.setTitle("Sign Up / Login", for: .normal)
            } catch (let error) {
                // This is where we deal with the error
                print(error)
            }
        }


    }

}
