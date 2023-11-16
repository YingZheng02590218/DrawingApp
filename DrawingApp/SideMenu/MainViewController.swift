//
//  MainViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/14.
//

import UIKit

class MainViewController: UIViewController {
    
    //    let contentViewController = UINavigationController(rootViewController: UIViewController())
    var contentViewController = UINavigationController(rootViewController: UIViewController())
    //    var contentViewController = UINavigationController(rootViewController: ApiClientViewController())
    let sidemenuViewController = SidemenuViewController()
    private var isShownSidemenu: Bool {
        return sidemenuViewController.parent == self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 継承したクラスで行う
        //         if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ApiClientViewController") as? ApiClientViewController {
        //             viewController.modalPresentationStyle = .fullScreen
        //             contentViewController = UINavigationController(rootViewController: viewController)
        //         }
        
        contentViewController.viewControllers[0].navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "list.bullet")?.withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(sidemenuBarButtonTapped(sender:)))
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.didMove(toParent: self)
        
        sidemenuViewController.delegate = self
        sidemenuViewController.startPanGestureRecognizing()
    }
    
    @objc private func sidemenuBarButtonTapped(sender: Any) {
        showSidemenu(animated: true)
    }
    
    private func showSidemenu(contentAvailability: Bool = true, animated: Bool) {
        if isShownSidemenu { return }
        
        addChild(sidemenuViewController)
        sidemenuViewController.view.autoresizingMask = .flexibleHeight
        sidemenuViewController.view.frame = contentViewController.view.bounds
        view.insertSubview(sidemenuViewController.view, aboveSubview: contentViewController.view)
        sidemenuViewController.didMove(toParent: self)
        if contentAvailability {
            sidemenuViewController.showContentView(animated: animated)
        }
    }
    
    private func hideSidemenu(animated: Bool) {
        if !isShownSidemenu { return }
        
        sidemenuViewController.hideContentView(animated: animated, completion: { (_) in
            self.sidemenuViewController.willMove(toParent: nil)
            self.sidemenuViewController.removeFromParent()
            self.sidemenuViewController.view.removeFromSuperview()
        })
    }
}

extension MainViewController: SidemenuViewControllerDelegate {
    func parentViewControllerForSidemenuViewController(_ sidemenuViewController: SidemenuViewController) -> UIViewController {
        return self
    }
    
    func shouldPresentForSidemenuViewController(_ sidemenuViewController: SidemenuViewController) -> Bool {
        /* You can specify sidemenu availability */
        return true
    }
    
    func sidemenuViewControllerDidRequestShowing(_ sidemenuViewController: SidemenuViewController, contentAvailability: Bool, animated: Bool) {
        showSidemenu(contentAvailability: contentAvailability, animated: animated)
    }
    
    func sidemenuViewControllerDidRequestHiding(_ sidemenuViewController: SidemenuViewController, animated: Bool) {
        hideSidemenu(animated: animated)
    }
    
    func sidemenuViewController(_ sidemenuViewController: SidemenuViewController, didSelectItemAt indexPath: IndexPath) {
        // サイドメニューを閉じる
        hideSidemenu(animated: true)
        
        print(contentViewController.viewControllers)
        print(self.presentingViewController) // Optional(<DrawingApp.SplashViewController: 0x101209d10>)
        print(self.presentedViewController)
        if let presentingViewController = contentViewController.viewControllers.first as? DrawingReportListViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                switch indexPath.row {
                case SideMenu.drawingReportRegister.getRow(): // 図面調書登録
                    // ファイル選択画面を表示させる
                    presentingViewController.showDocumentPicker()
                    break
                case SideMenu.photoReportRegister.getRow(): // 写真調書登録
                    break
                case SideMenu.pictureRegister.getRow(): // 撮影写真登録
                    break
                case SideMenu.project.getRow(): // プロジェクト
                    break
                default:
                    break
                }
            }
        }
    }
    
}
