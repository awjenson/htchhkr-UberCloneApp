//
//  LoginVC.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/29/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import Firebase

class LoginVC: UIViewController, UITextFieldDelegate, Alertable {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var emailField: RoundedCornerTextField!

    @IBOutlet weak var passwordField: RoundedCornerTextField!
    
    @IBOutlet weak var authBtn: RoundedShadowButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        emailField.delegate = self
        passwordField.delegate = self

        view.bindToKeyboard()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }

    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func authBtnWasPressed(_ sender: Any) {
        if emailField.text != nil && passwordField.text != nil {
            authBtn.animateButton(shouldLoad: true, withMessage: nil)
            self.view.endEditing(true)

            // This is the function that logs in an existing user
            if let email = emailField.text, let password = passwordField.text {
                Auth.auth().signIn(withEmail: email, password: password, completion: { (user, error) in
                    // if no error, then return the user's data
                    if error == nil {
                        // update whether user is a driver or user/passenger
                        if let user = user {
                            if self.segmentedControl.selectedSegmentIndex == 0 {
                                let userData = ["provider": user.providerID] as [String: Any]
                                // Get data into database
                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: false)
                            } else if self.segmentedControl.selectedSegmentIndex == 1 {
                                let userData = ["provider": user.providerID, "userIsDriver": true, "isPickeupModeEnabled": false, "driverIsOnTrip": false] as [String: Any]
                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: true)
                            }
                        }
                        print("Email user auth success with Firebase")
                        self.dismiss(animated: true, completion: nil)
                    } else {

                        if let errorCode = AuthErrorCode(rawValue: error!._code) {
                            switch errorCode {
                            case .wrongPassword:
                                self.showAlert("Whoops! Wrong password.")
                            default:
                                self.showAlert("An unexpected error occured. Please try again.")
                            }
                        }

                        // No existing user account found. Create New USER.
                        Auth.auth().createUser(withEmail: email, password: password, completion: { (user, error) in
                            if error != nil {
                                if let errorCode = AuthErrorCode(rawValue: error!._code) {
                                    switch errorCode {
                                    case .invalidEmail:
                                        self.showAlert("That is an invalid email. Please try again.")
                                    default:
                                        self.showAlert("An unexpected error occured. Please try again.")
                                        
                                    }
                                }
                            } else {
                                // We typed in a unique email and password and there are no errors
                                if let user = user {
                                    // passenger
                                    if self.segmentedControl.selectedSegmentIndex == 0 {
                                        let userData = ["provider": user.providerID] as [String: Any]
                                        DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: false)
                                    } else {
                                        let userData = ["provider": user.providerID, "userIsDriver": true, "isPickupModeEnabled": false, "driverIsOnTrip": false] as [String: Any]
                                        DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: true)
                                    }
                                }
                                print("Successfully created a new user with Firebase")
                                self.dismiss(animated: true, completion: nil)
                            }

                        })

                    }
                })
            }
        }
    }
}
