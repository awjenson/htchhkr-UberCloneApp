//
//  ContainerVC.swift
//  htchhkr-development
//
//  Created by Andrew Jenson on 1/24/18.
//  Copyright © 2018 Andrew Jenson. All rights reserved.
//

import UIKit
import QuartzCore

// Enums will give us cases to monitor if our menu is open/closed and which VC to display.
enum SlideOutState {
    case collapsed
    case leftPanelExpanded

}

enum ShowWhichVC {
    case homeVC
}

// Variable to keep track of which VC were currently working with
var showVC: ShowWhichVC = .homeVC

class ContainerVC: UIViewController {

    // Create homeVC and leftVC variables to store the View Controllers so later we can instantiate them properly below.
    var homeVC: HomeVC!
    var leftVC: LeftSidePanelVC!
    // A VC that we'll use as a temp container
    var centerController: UIViewController!

    // for extension Container CenterVCDelegate, initally set to collapsed because when it first launches, we don't want it to be open
    var currentState: SlideOutState = .collapsed {
        didSet {
            let shouldShowShadow = (currentState != .collapsed)
            shouldShowShadowForCenterViewController(status: shouldShowShadow)
        }
    }

    //
    var isHidden = false
    let centerPanelExpandedOffset: CGFloat = 160

    var tap: UITapGestureRecognizer!


    override func viewDidLoad() {
        super.viewDidLoad()

        initCenter(screen: showVC)
    }

    func initCenter(screen: ShowWhichVC) {
        // presentingController holds our VC in place until we can set it as the center most VC
        var presentingController: UIViewController

        showVC = screen

        if homeVC == nil {
            homeVC = UIStoryboard.homeVC()
            homeVC.delegate = self
        }

        presentingController = homeVC

        // Before we pass in a new VC, we need to clear out any existing VCs and clean up memory
        if let con = centerController {
            con.view.removeFromSuperview()
            con.removeFromParentViewController()
        }

        centerController = presentingController

        // Take centerController and added its view as a subview on our containerVC
        view.addSubview(centerController.view)
        // We have added he centerController as well
        addChildViewController(centerController)
        // Moved it to the parentVC.
        // self is our containVC
        centerController.didMove(toParentViewController: self)
    }

    // override properties
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }

    override var prefersStatusBarHidden: Bool {
        // if isHidden is true, it will slide up. If isHidden is false, it will slide down.
        return isHidden
    }
}

extension ContainerVC: CenterVCDelegate {
    // 3 methods needed to conform to delegate

    func toggleLeftPanel() {
        // is it already expanded? If yes, then close it.  If no, then add controller behind it and animate it to expand
        // 'notAlreadyExpanded' means the currentState property is not equal to leftPanelExpanded
        let notAlreadyExpanded = (currentState != .leftPanelExpanded)

        if notAlreadyExpanded {
            addLeftPanelViewController()
        }
        // animation depends on whether notAlreadyExpanded is true or false. Since we start the app at collapsed, it is true and it should expand and when we tap the button it will open the menu.
        animateLeftPanel(shouldExpand: notAlreadyExpanded)

    }

    func addLeftPanelViewController() {
        // Before we can add in the leftVC, we need to create a new variable above that instantiates the leftVC.
        if leftVC == nil {
            // Add the childSidePanel below the current view controller
            leftVC = UIStoryboard.leftViewController()
            // in order to place it behind the current view controller
            addChildSidePanelViewController(leftVC!)
        }
    }

    @objc func animateLeftPanel(shouldExpand: Bool) {
        // Add a shadow under the top VC and slide it to the right, we'll create a couple different properties to do this.
        if shouldExpand {
            isHidden = !isHidden
            animateStatusBar()

            setupWhiteCoverView()

            currentState = .leftPanelExpanded

            // call the method without the completionHandler property (only targetPosition porperty)
            animateCenterPanelXPosition(targetPosition: centerController.view.frame.width - centerPanelExpandedOffset)
        } else {
            isHidden = !isHidden
            animateStatusBar()

            hideWhiteCoverView()
            animateCenterPanelXPosition(targetPosition: 0, completion: { (finished) in
                if finished == true {
                    self.currentState = .collapsed
                    self.leftVC = nil
                }
            })
        }
    }

    func animateCenterPanelXPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.centerController.view.frame.origin.x = targetPosition
        }, completion: completion)
    }

    func setupWhiteCoverView() {
        // Create a UIView, set it to be sort of transparent, alpha to 0, add a tap gesture recognizer
        let whiteCoverView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        whiteCoverView.alpha = 0.0
        whiteCoverView.backgroundColor = UIColor.white
        whiteCoverView.tag = 25
        self.centerController.view.addSubview(whiteCoverView)
        // After it has been added, we can create an animation
        whiteCoverView.fadeTo(alphaValue: 0.75, withDuration: 0.2)

        // Setup the tapGestureRecognizer when we setup the view in the first place.
        // When we tap on this, it's going to animate the left panel to be closed
        tap = UITapGestureRecognizer(target: self, action: #selector(animateLeftPanel(shouldExpand:)))
        tap.numberOfTapsRequired = 1
        self.centerController.view.addGestureRecognizer(tap)
    }

    func hideWhiteCoverView() {
        // remove gesture recognizer
        centerController.view.removeGestureRecognizer(tap)

        for subview in self.centerController.view.subviews {
            if subview.tag == 25 {
                // animate the transparency down to 0 and remove it from the superView
                // Keep this code as is (don't replace with .fadeTo because the fading needs to happen before its removed from the superView
                UIView.animate(withDuration: 0.2, animations: {
                    subview.alpha = 0.0
                }, completion: { (finished) in
                    subview.removeFromSuperview()
                })


            }
        }
    }

    func shouldShowShadowForCenterViewController(status: Bool) {
        if status == true {
            centerController.view.layer.shadowOpacity = 0.6
        } else {
            centerController.view.layer.shadowOpacity = 0.0
        }
    }

    func animateStatusBar() {
        // We don't need the copmletionHandler in this method call
        UIView.animate(withDuration: 0.5, delay: 0.8, usingSpringWithDamping: 0.0, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
    }

    func addChildSidePanelViewController(_ sidePanelController: LeftSidePanelVC) {
        // at 0 is the furthest backmost VC
        view.insertSubview(sidePanelController.view, at: 0)
        // make sure addChildViewController is adding type UIViewController
        addChildViewController(sidePanelController)
        sidePanelController.didMove(toParentViewController: self)
    }
}

// Private because we only want ContainerVC to have access to this extension. Make it easy for ContainerVC to access the storyboard and all VCs in the app
private extension UIStoryboard {

    // We're using 'class' because we want it to be used and overwritten by this class to modify the storyboard and VCs.
    class func mainStoryBoard() -> UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle.main)
    }

    class func leftViewController() -> LeftSidePanelVC? {
        return mainStoryBoard().instantiateViewController(withIdentifier: "LeftSidePanelVC") as? LeftSidePanelVC
    }

    class func homeVC() -> HomeVC? {
        return mainStoryBoard().instantiateViewController(withIdentifier: "HomeVC") as? HomeVC
    }


}
