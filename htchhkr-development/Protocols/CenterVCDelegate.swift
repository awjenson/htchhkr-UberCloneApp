//
//  CenterVCDelegate.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/24/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import Foundation

// Toggle it open/close, add leftPanel, and animate the VC behind it.

protocol CenterVCDelegate {
    func toggleLeftPanel()
    func addLeftPanelViewController()
    func animateLeftPanel(shouldExpand: Bool)
}
