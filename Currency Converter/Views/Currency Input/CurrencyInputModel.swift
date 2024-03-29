//
//  CurrencyInputModel.swift
//  Currency Converter
//
//  Created by Nata Khurtsidze on 28.06.22.
//

import UIKit

// MARK: - Currency Input Model
struct CurrencyInputModel {
    // MARK: Properties
    var layout: Layout = .init()
    var color: Color = .init()
    var font: Font = .init()
    
    // MARK: Layout
    struct Layout {
        let spacing: CGFloat = 8
        
        let iconDimension: CGSize = .init(width: 40, height: 40)
        let toolbarDimension: CGSize = .init(width: 300, height: 40)
        
        let currencyWrapperWidth: CGFloat = 60
        
        let inputFieldWidth: CGFloat = 100
    }
    
    // MARK: Color
    struct Color {
        var iconTint: UIColor = .blue
        var inputLabel: UIColor = .blue
        
        var inputText: UIColor = .black
        var background: UIColor = .white
    }
    
    // MARK: Font
    struct Font {
        var inputLabel: UIFont = .systemFont(ofSize: 16)
        var currency: UIFont = .systemFont(ofSize: 16)
    }
}
