//
//  SplashViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit

class SplashViewController: UIViewController {
    
    // インジゲーターの設定
    var indicator = UIActivityIndicatorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 表示位置を設定（画面中央）
        self.indicator.center = self.view.center
        // インジケーターのスタイルを指定（白色＆大きいサイズ）
        self.indicator.style = UIActivityIndicatorView.Style.large
        // インジケーターの色を設定（青色）
        self.indicator.color = .red//UIColor(red: 44/255, green: 169/255, blue: 225/255, alpha: 1)
        // インジケーターを View に追加
        self.view.addSubview(self.indicator)
        // インジケーターを表示＆アニメーション開始
        self.indicator.startAnimating()
    }
    
    // 注意
    // instantiateViewController　をviewDidLoad() から呼び出すと、次の警告が表示されて、Viewの遷移ができない。
    // Warning: Attempt to present <***.ViewController: 0x104910db0> on <***.SplashViewController: 0x10490a030> whose view is not in the window hierarchy!
    // 原因については、次の記事にあるように、まだ ViewController が存在していないのに、遷移しようとしたため。
    // 対応としては、viewDidAppear の中で遷移する。
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // メインスレッドでインジケーターを停止する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 非同期処理などを実行（今回は2秒間待つだけ）
            Thread.sleep(forTimeInterval: 0.2)
            // インジケーターを非表示＆アニメーション終了
            self.indicator.stopAnimating()
            
            if let viewController = UIStoryboard(
                name: "WrappingMainViewController",
                bundle: nil
            ).instantiateViewController(withIdentifier: "WrappingMainViewController") as? WrappingMainViewController {
                viewController.modalPresentationStyle = .fullScreen
                viewController.modalTransitionStyle = .crossDissolve
                self.present(viewController, animated: false, completion: nil)
            }
        }
    }
}
