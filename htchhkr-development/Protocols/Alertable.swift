//
//  Alertable.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 2/5/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

protocol Alertable {}

extension Alertable where Self: UIViewController {
    func showAlert(_ msg: String) {
        let alertController = UIAlertController(title: "Error:", message: msg, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)

        alertController.addAction(action)
        present(alertController, animated: true, completion: nil)
    }
}
