//
//  ImageAnnotation.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/10/02.
//

import PDFKit
import UIKit
//PDFKitで表示したPDFViewへ画像を追加する
//さて、表示したPDFへ画像の追加を行う処理を組み込みましょう。
//
//まずPDFKitで行えるPDFの編集手段を挙げていきます。
//
//例えば編集対象のページを一旦UIImageとして書き出してしまい、手書き内容と結合したUIImageをまたPDFとして書き出しPDFDocumentへinsert(_ page: PDFPage, at index: Int)メソッドを利用してページとして追加する方法がありますが、この方法ではPDFページ内に含まれる文字情報が画像化に伴い完全に消えてしまうといったデメリットがあります。
//
//それを回避するために、今回はPDFの注釈機能を利用して画像を追加する方法を紹介します。
//
//PDFの注釈を利用するためにはPDFAnnotationクラスを利用します。そのままではコードから画像付きの注釈を生成できないので、次のサブクラスを作成してください。
class ImageAnnotation: PDFAnnotation {
    
    var image: UIImage!
    
    init(with image: UIImage!, forBounds bounds: CGRect, withProperties properties: [AnyHashable : Any]?) {
        // 注釈を設定したいPDFPageを指定して、定義したPDFAnnotationを設定します。
        // 他にも様々な種類のPDFAnnotationSubTypeを指定して利用できます。
        // (参考: https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype)
        super.init(bounds: bounds, forType: .stamp, withProperties: properties)
        self.image = image.withRenderingMode(.alwaysTemplate)
        self.fontColor = .systemPink
        self.color = .green
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // このImageAnnotationクラスではPDFAnnotationクラスの描画を担当するdraw(with box: PDFDisplayBox, in context: CGContext)メソッドをオーバーライドすることでコード上で指定した画像をPDF上に描画できるようにカスタマイズしています。
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = self.image.cgImage else { return }
        context.draw(cgImage, in: self.bounds)
    }

}
class PhotoAnnotation: PDFAnnotation {
}
