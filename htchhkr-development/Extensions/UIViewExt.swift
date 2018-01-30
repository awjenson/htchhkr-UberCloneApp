//
//  UIViewExt.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/29/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

extension UIView {
    func fadeTo(alphaValue: CGFloat, withDuration duration: TimeInterval) {
        UIView.animate(withDuration: duration) {
            self.alpha = alphaValue
        }
    }
}
