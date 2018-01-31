//
//  LoginVC.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/29/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

class LoginVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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



}
