//
//  CircleView.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/23/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

class CircleView: UIView {

    // IBInspector will allow us to modify the boarder and color seperately
    @IBInspectable var boardColor: UIColor? {
        didSet {
            setupView()
        }
    }

    override func awakeFromNib() {
        setupView()
    }

    func setupView() {
        self.layer.cornerRadius = self.frame.width / 2
        self.layer.borderWidth = 1.5
        self.layer.borderColor = boardColor?.cgColor
    }

}
