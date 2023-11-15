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
        
        if let viewController = UIStoryboard(name: "ViewController", bundle: nil).instantiateViewController(withIdentifier: "ViewController") as? ViewController {
            viewController.modalPresentationStyle = .fullScreen
            contentViewController = UINavigationController(rootViewController: viewController)
        }
        contentViewController.viewControllers[0].navigationItem.title = "一覧"
        super.viewDidLoad()
    }
}