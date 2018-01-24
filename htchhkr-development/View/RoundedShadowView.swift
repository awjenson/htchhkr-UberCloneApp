//
//  RoundedShadowView.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/23/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

class RoundedShadowView: UIView {

    override func awakeFromNib() {
        setupView()
    }

    func setupView() {
        // round corner radius
        self.layer.cornerRadius = 5.0

        // drop shadow
        self.layer.shadowOpacity = 0.3
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowRadius = 5.0
        self.layer.shadowOffset = CGSize(width: 0, height: 5)
    }

}
