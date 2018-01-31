//
//  RoundedCornerTextField.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/30/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit

class RoundedCornerTextField: UITextField {

    var textRectOffset: CGFloat = 20

    override func awakeFromNib() {
        setupView()

    }

    func setupView() {
        // round textfield
        self.layer.cornerRadius = self.frame.height / 2
        // xCode 9 requirement to get rounded textfield
//        self.clipsToBounds = true
    }

    // xCode 9 makes rounded corners with only the setupView code above, we do not need to add in the functions below

//    // 1/2 - Return same rectangle for displaying and editing
//    override func textRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
//    }
//
//    // 2/2 - Return same rectangle for displaying and editing
//    override func editingRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
//    }
//
//    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
//        return CGRect(x: 0 + textRectOffset, y: 0 , width: self.frame.width - textRectOffset, height: self.frame.height)
//    }


}
