//
//  TextInputViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/09.
//

import UIKit

class TextInputViewController: UIViewController {
    @IBOutlet var baseView: UIView!
    @IBOutlet var headerView: UIView!
    @IBOutlet var bodyView: UIView!
    @IBOutlet var footerView: UIView!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var textField: UITextField!
    @IBOutlet var slider: UISlider!
    @IBOutlet var smallButton: UIButton!
    @IBOutlet var bigButton: UIButton!
    @IBOutlet var fontSizeLabel: UILabel!
    @IBOutlet var okButton: UIButton!
    @IBOutlet var cancelButton: UIButton!

    var text: String?
    var fontSize: CGFloat = 15.0 {
        didSet {
            if let fontSizeLabel = fontSizeLabel {
                fontSizeLabel.text = "\(Int(fontSize)) px"
            }
        }
    }
    var annotationIsEditing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // タイトル
        titleLabel.text = Title.textInput.description
        // フォントサイズ
        slider.value = Float(fontSize)
        // 初期表示
        textField.text = text
        textField.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        DispatchQueue.main.async {
            self.headerView.addBorder(width: 0.3, color: UIColor.gray, position: .bottom)
            self.footerView.addBorder(width: 0.3, color: UIColor.gray, position: .top)
        
            self.textField.addBorder(width: 0.3, color: UIColor.gray, position: .bottom)
        }
        // UIViewに角丸な枠線(破線/点線)を設定する
        // https://xyk.hatenablog.com/entry/2016/11/28/185521
        baseView.layer.borderColor = UIColor.white.cgColor
        baseView.layer.borderWidth = 0.1
        baseView.layer.cornerRadius = 15
        baseView.layer.masksToBounds = true
        // 右上と左下を角丸にする設定
        okButton.layer.borderColor = UIColor.gray.cgColor
        okButton.layer.borderWidth = 0.1
        okButton.layer.cornerRadius = okButton.frame.height / 2
        okButton.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        // 右上と左下を角丸にする設定
        cancelButton.layer.borderColor = UIColor.gray.cgColor
        cancelButton.layer.borderWidth = 0.1
        cancelButton.layer.cornerRadius = cancelButton.frame.height / 2
        cancelButton.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        fontSize = CGFloat(sender.value)
    }
    
    @IBAction func smallButtonTapped(_ sender: Any) {
        slider.value -= 1.0
        fontSize = CGFloat(slider.value)
    }
    
    @IBAction func bigButtonTapped(_ sender: Any) {
        slider.value += 1.0
        fontSize = CGFloat(slider.value)
    }
    
    @IBAction func okButtonTapped(_ sender: Any) {
        print(presentingViewController)
        print(presentedViewController)
        
        // タブで選択中のナビゲーションコントローラ
        guard let navigationController = presentingViewController as? UINavigationController else {
            print("Could not find avigation nController")
            return
        }
        // ナビゲーションコントローラの最前面を取得
        if let viewController = navigationController.topViewController as? DrawingViewController { // 呼び出し元のビューコントローラーを取得
            self.dismiss(animated: true, completion: { [viewController] () -> Void in
                if self.annotationIsEditing {
                    // マーカーを更新する テキスト
                    viewController.updateTextMarkerAnotation(
                        inputText: self.textField.text,
                        fontSize: self.fontSize
                    )
                } else {
                    // マーカーを追加する テキスト
                    viewController.addTextMarkerAnotation(
                        inputText: self.textField.text,
                        fontSize: self.fontSize
                    )
                }
            })
        }
        // ナビゲーションコントローラの最前面を取得
        if let viewController = navigationController.topViewController as? DrawingReportEditViewController { // 呼び出し元のビューコントローラーを取得
            self.dismiss(animated: true, completion: { [viewController] () -> Void in
                if self.annotationIsEditing {
                    // マーカーを更新する テキスト
                    viewController.updateTextMarkerAnotation(
                        inputText: self.textField.text,
                        fontSize: self.fontSize
                    )
                } else {
                    // マーカーを追加する テキスト
                    viewController.addTextMarkerAnotation(
                        inputText: self.textField.text,
                        fontSize: self.fontSize
                    )
                }
            })
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        
        dismiss(animated: true, completion: nil)
    }
}

extension TextInputViewController: UITextFieldDelegate {
    // リターンキー押下でキーボードを閉じる
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

enum Title: CustomStringConvertible {
    // テキストの入力
    case textInput
    
    var description: String {
        switch self {
        case .textInput:
            return "テキストの入力"
        }
    }
}
