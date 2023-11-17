//
//  WrappingMainViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit

// サイドメニュー画面を継承したViewController
class WrappingMainViewController: MainViewController {
    
    var segmentedControlTab: SegmentedControlTab = .drawingReportList
    
    override func viewDidLoad() {
        
        switch segmentedControlTab {
        case .drawingReportList:
            if let viewController = UIStoryboard(name: "DrawingReportListViewController", bundle: nil).instantiateViewController(withIdentifier: "DrawingReportListViewController") as? DrawingReportListViewController {
                viewController.modalPresentationStyle = .fullScreen
                contentViewController = UINavigationController(rootViewController: viewController)
            }
            contentViewController.viewControllers[0].navigationItem.title = "図面調書一覧"
        case .photoReportList:
            if let viewController = UIStoryboard(name: "PhotoLisViewController", bundle: nil).instantiateViewController(withIdentifier: "PhotoLisViewController") as? PhotoLisViewController {
                viewController.modalPresentationStyle = .fullScreen
                contentViewController = UINavigationController(rootViewController: viewController)
            }
            contentViewController.viewControllers[0].navigationItem.title = "撮影写真一覧"
        }
        super.viewDidLoad()
    }
}
