//
//  CreateEventBottomSheetPresentationController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

class CreateEventBottomSheetPresentationController: UIPresentationController {

    private let sheetHeight: CGFloat = 350

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        return CGRect(
            x: 0,
            y: containerView.bounds.height - sheetHeight,
            width: containerView.bounds.width,
            height: sheetHeight
        )
    }

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }

        let dimmingView = UIView(frame: containerView.bounds)
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimmingView.alpha = 0
        containerView.insertSubview(dimmingView, at: 0)

        // Add tap gesture recognizer to dismiss the keyboard when tapping the dimming view
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dimmingView.addGestureRecognizer(tapGestureRecognizer)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            dimmingView.alpha = 1
        }, completion: nil)
    }
    
    @objc func dismissKeyboard() {
            // Dismiss the keyboard when tapping on the dimming view
            presentedViewController.view.endEditing(true)
        }

    override func dismissalTransitionWillBegin() {
        containerView?.subviews.first?.alpha = 0
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            containerView?.subviews.first?.removeFromSuperview()
        }
    }
}
