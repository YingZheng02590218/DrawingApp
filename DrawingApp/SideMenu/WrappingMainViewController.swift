//
//  WrappingMainViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit

// サイドメニュー画面を継承したViewController
class WrappingMainViewController: MainViewController {
        
    override func viewDidLoad() {
        
        if let viewController = UIStoryboard(
            name: "SegmentedControlPageViewController",
            bundle: nil
        ).instantiateViewController(withIdentifier: "SegmentedControlPageViewController") as? SegmentedControlPageViewController {
            viewController.modalPresentationStyle = .fullScreen
            contentViewController = UINavigationController(rootViewController: viewController)
        }
        super.viewDidLoad()
    }
}
