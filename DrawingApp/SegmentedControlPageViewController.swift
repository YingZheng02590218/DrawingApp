//
//  SegmentedControlPageViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/17.
//

import UIKit

// ホーム画面
class SegmentedControlPageViewController: UIViewController {

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    var pageViewController: UIPageViewController!
    var drawingReportListViewController: WrappingMainViewController!
    var photoLisViewController: WrappingMainViewController!

    let idArray = SegmentedControlTab.allCases
    
    var viewControllers = [UIViewController]()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for id in idArray {
            if let viewController = UIStoryboard(
                name: "WrappingMainViewController",
                bundle: nil
            ).instantiateViewController(withIdentifier: "WrappingMainViewController") as? WrappingMainViewController {
                viewController.modalPresentationStyle = .fullScreen
                viewController.modalTransitionStyle = .crossDissolve
                viewController.segmentedControlTab = id
                if id == .drawingReportList {
                    drawingReportListViewController = viewController
                } else {
                    photoLisViewController = viewController
                }
                viewControllers.append(viewController)
            }
        }
        
        pageViewController = children.first as? UIPageViewController
        pageViewController.setViewControllers([viewControllers[0]], direction: .forward, animated: false, completion: nil)
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged(segmentedControl:)), for: UIControl.Event.valueChanged)
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
        if let vcName = pageViewController.viewControllers?.first?.restorationIdentifier {
            let index = idArray.firstIndex(of: SegmentedControlTab(rawValue: vcName) ?? .drawingReportList)
            segmentedControl.selectedSegmentIndex = index!
        }
    }
}

enum SegmentedControlTab: String, CaseIterable {
    case drawingReportList = "DrawingReportListViewController"
    case photoReportList = "PhotoLisViewController"
}
