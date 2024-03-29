//
//  CurrencyInputDelegate.swift
//  Currency Converter
//
//  Created by Nata Khurtsidze on 28.06.22.
//

import Foundation

// MARK: - Currency Input Delegate
protocol CurrencyInputDelegate: AnyObject {
    func didChangeAmount(sender: CurrencyInput, amount: Double, currency: Currency)
    func didTapCurrencyButton(sender: CurrencyInput)
    func didBeginAmountEditing(sender: CurrencyInput) 
}
