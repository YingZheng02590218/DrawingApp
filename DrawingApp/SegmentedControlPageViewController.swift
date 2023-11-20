//
//  SegmentedControlPageViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/17.
//

import UIKit

// ホーム画面
class SegmentedControlPageViewController: InportViewController {

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    var pageViewController: UIPageViewController!
    var drawingReportListViewController: UINavigationController!
    var photoLisViewController: UINavigationController!

    let segmentedControlTabs = SegmentedControlTab.allCases
    
    var viewControllers = [UIViewController]()

    // スワイプジェスチャーを禁止
    static let needToChangeSwipeEnabledNotification = Notification.Name("NotificationForChangeMainPageSwipeEnabled")
    // スワイプジェスチャーを禁止
    private func changeSwipeEnabled(to canSwipe: Bool) {
        pageViewController.dataSource = canSwipe ? self : nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for segmentedControlTab in segmentedControlTabs {
            switch segmentedControlTab {
            case .drawingReportList:
                if let viewController = UIStoryboard(name: "DrawingReportListViewController", bundle: nil).instantiateViewController(withIdentifier: "DrawingReportListViewController") as? DrawingReportListViewController {
                    viewController.modalPresentationStyle = .fullScreen
                    viewController.modalTransitionStyle = .crossDissolve
                    drawingReportListViewController = UINavigationController(rootViewController: viewController)
                    viewControllers.append(drawingReportListViewController)
                }
            case .photoReportList:
                if let viewController = UIStoryboard(name: "PhotoLisViewController", bundle: nil).instantiateViewController(withIdentifier: "PhotoLisViewController") as? PhotoLisViewController {
                    viewController.modalPresentationStyle = .fullScreen
                    viewController.modalTransitionStyle = .crossDissolve
                    photoLisViewController = UINavigationController(rootViewController: viewController)
                    viewControllers.append(photoLisViewController)
                }
            }
        }
        
        pageViewController = children.first as? UIPageViewController
        pageViewController.setViewControllers([viewControllers[0]], direction: .forward, animated: false, completion: nil)
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged(segmentedControl:)), for: UIControl.Event.valueChanged)
        
        // スワイプジェスチャーを禁止
        NotificationCenter.default
            .addObserver(forName: SegmentedControlPageViewController.needToChangeSwipeEnabledNotification,
                         object: nil,
                         queue: nil,
                         using: { [weak self] notification in
                            guard let canSwipe = notification.object as? Bool else { return }
                            self?.changeSwipeEnabled(to: canSwipe)
                         })

    }
    
    @objc 
    func segmentedControlChanged(segmentedControl: UISegmentedControl) {
        
        let index = segmentedControl.selectedSegmentIndex
        switch index {
        case 0:
            pageViewController.setViewControllers([viewControllers[index]], direction: .reverse, animated: true, completion: nil)
        case 1:
            pageViewController.setViewControllers([viewControllers[index]], direction: .forward, animated: true, completion: nil)
        default:
            break
        }
    }
    
    // UIをリロード
    override func reload() {
        if let viewController = viewControllers[segmentedControl.selectedSegmentIndex] as? UINavigationController {
            if let viewController = viewController.viewControllers.first as? DrawingReportListViewController {
                viewController.reload()
            }
            if let viewController = viewController.viewControllers.first as? PhotoLisViewController {
                viewController.reload()
            }
        }
    }
}

extension SegmentedControlPageViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let index = viewControllers.firstIndex(of: viewController), index > 0 {
            return viewControllers[index-1]
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let index = viewControllers.firstIndex(of: viewController), index < viewControllers.count-1 {
            return viewControllers[index+1]
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        // viewControllerBefore と viewControllerAfter　は2回処理が走ってインデックスがずれるので、アニメーション完了後にインデックスを取得
        if let navigationController = pageViewController.viewControllers?.first,
           let currentVC = navigationController.children.first {
            if currentVC.isKind(of: DrawingReportListViewController.self) {
                segmentedControl.selectedSegmentIndex = 0
            } else if currentVC.isKind(of: PhotoLisViewController.self) {
                    segmentedControl.selectedSegmentIndex = 1
            }
        }
    }
}

enum SegmentedControlTab: String, CaseIterable {
    case drawingReportList = "DrawingReportListViewController"
    case photoReportList = "PhotoLisViewController"
}
