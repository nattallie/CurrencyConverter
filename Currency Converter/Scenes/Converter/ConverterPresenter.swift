//
//  ConverterPresenter.swift
//  Currency Converter
//
//  Created by Nata Khurtsidze on 26.06.22.
//

import Foundation

// MARK: - Converter Presenter
final class ConverterPresenter: ConverterPresentable {
    // MARK: Properties
    var numberOfCurrencies: Int { viewModel.accountItems.count }
    var defaultCurrency: Currency { viewModel.accountItems.first?.currency ?? Currency.EUR }
    var defaultAmount: Double { 0 }
    
    var sellInputTitle: String { Consts.Scenes.Converter.sellTitle }
    var receiveInputTitle: String { Consts.Scenes.Converter.receiveTitle }
    
    private unowned let view: ConverterView
    private var viewModel: ConverterViewModel
    private let converterUseCase: CurrencyConverterUseCase
    
    private var lastSelectedCurrencyInput: CurrencyInputType? = nil
    private var numberOfConversions: Int = 0
    
    private var isFreeConversion: Bool {
        numberOfConversions < viewModel.numberOfFreeExchange
    }
    
    // MARK: Initializers
    init(
        view: ConverterView,
        viewModel: ConverterViewModel,
        converterUseCase: CurrencyConverterUseCase
    ) {
        self.view = view
        self.viewModel = viewModel
        self.converterUseCase = converterUseCase
    }
    
    // MARK: Converter Presentable
    func viewDidLoad() {
        view.setTitle(Consts.Scenes.Converter.title)
        view.setBalanceTitle(Consts.Scenes.Converter.balanceTitle)
        view.setAccountItems(viewModel.accountItems)
        view.setCurrencyExchangeTitle(Consts.Scenes.Converter.exchangeTitle)
        view.setButtonTitle(Consts.Scenes.Converter.converterButtonTitle)
        view.setButtonActivity(to: true)
    }
    
    func titleForCurrency(at index: Int) -> String {
        guard (0..<viewModel.accountItems.count).contains(index) else {
            fatalError()
        }
        
        return viewModel.accountItems[index].currency.rawValue
    }
    
    // MARK: Conversion Processing
    func didChangeAmount(inputType: CurrencyInputType, amount: Double, currency: Currency) {
        var toCurrency: Currency
        var destinationInput: CurrencyInputType
        
        switch inputType {
        case .sell:
            toCurrency = view.receiveCurrency
            destinationInput = .receive
        case .receive:
            toCurrency = view.sellCurrency
            destinationInput = .sell
        }
        
        processConversion(
            fromAmount: amount,
            fromCurrency: currency,
            toCurrency: toCurrency,
            destinationInput: destinationInput
        )
    }
    
    private func processConversion(
        fromAmount: Double,
        fromCurrency: Currency,
        toCurrency: Currency,
        destinationInput: CurrencyInputType
    ) {
        Task {
            await sendConversionCall(
                fromAmount: fromAmount,
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                destinationInput: destinationInput
            )
        }
    }
    
    @MainActor private func sendConversionCall(
        fromAmount: Double,
        fromCurrency: Currency,
        toCurrency: Currency,
        destinationInput: CurrencyInputType
    ) async {
        view.startLoading()
        view.setScreenInteraction(to: false)
        
        do {
            let conversionEntity: CurrencyConverterEntity? = try await converterUseCase.fetch(
                parameters: .init(
                    fromAmount: fromAmount,
                    fromCurrency: fromCurrency.rawValue,
                    toCurrency: toCurrency.rawValue
                )
            )
            
            view.stopLoading()
            view.setScreenInteraction(to: true)
            
            guard let conversionEntity = conversionEntity else {
                view.showAlert(viewModel: .init(
                    title: Consts.Common.errorOccured,
                    message: Consts.Network.networkError,
                    actionTitle: Consts.Common.OK
                ))
                return
            }

            view.setCurrentAmount(Double(conversionEntity.amount) ?? 0, inputType: destinationInput)
            
            view.setButtonActivity(to: isValidConversion(sellAmount: view.sellAmount, currency: view.sellCurrency))
        } catch {
            view.stopLoading()
            view.setScreenInteraction(to: true)
            
            view.showAlert(viewModel: .init(
                title: Consts.Common.errorOccured,
                message: (error as? NetworkError)?.localizedDescription ?? "",
                actionTitle: Consts.Common.OK
            ))
        }
    }
    
    private func isValidConversion(sellAmount: Double, currency: Currency) -> Bool {
        guard
            let accountIndex = viewModel.accountItems.firstIndex(where: { $0.currency == currency } )
        else {
            return false
        }
        
        var fee: Double = sellAmount * viewModel.commissionPercentage
        if isFreeConversion {
            fee = 0
        }
        
        return sellAmount <= viewModel.accountItems[accountIndex].amount + fee
    }
    
    func didTapCurrencyButton(inputType: CurrencyInputType) {
        lastSelectedCurrencyInput = inputType
        
        switch lastSelectedCurrencyInput {
        case .sell:
            let currencyIndex: Int? = viewModel.accountItems.firstIndex(where: { $0.currency == view.sellCurrency } )
            if let index = currencyIndex {
                view.showCurrencySelectorPopUp(selectedCurrencyIndex: index)
            }
        case .receive:
            let currencyIndex: Int? = viewModel.accountItems.firstIndex(where: { $0.currency == view.receiveCurrency } )
            if let index = currencyIndex {
                view.showCurrencySelectorPopUp(selectedCurrencyIndex: index)
            }
        case .none:
            break
        }
    }
    
    func didSelectCurrency(_ index: Int) {
        view.dismissCurrencySelectorPopUp()
        if let lastSelected = lastSelectedCurrencyInput {
            view.setCurrentCurrency(viewModel.accountItems[index].currency, inputType: lastSelected)
            
            switch lastSelected {
            case .sell:
                processConversion(
                    fromAmount: view.sellAmount,
                    fromCurrency: view.sellCurrency,
                    toCurrency: view.receiveCurrency,
                    destinationInput: .receive
                )
            case .receive:
                processConversion(
                    fromAmount: view.receiveAmount,
                    fromCurrency: view.receiveCurrency,
                    toCurrency: view.sellCurrency,
                    destinationInput: .sell
                )
            }
        }
    }
    
    // MARK: Submit Button actions
    func didTapSubmitButton() {
        view.setScreenInteraction(to: false)
        
        let fromAmount: Double = view.sellAmount
        let toAmount: Double = view.receiveAmount
        
        guard
            let fromIndex = viewModel.accountItems.firstIndex(where: { $0.currency == view.sellCurrency } ),
            let toIndex = viewModel.accountItems.firstIndex(where: { $0.currency == view.receiveCurrency } )
        else {
            return
        }
        
        let message: String = updateAccountsAndGetMessage(
            fromAmount: fromAmount,
            toAmount: toAmount,
            fromIndex: fromIndex,
            toIndex: toIndex
        )

        view.setScreenInteraction(to: true)
        
        view.showAlert(viewModel: .init(
            title: Consts.Scenes.Converter.successfulConversion,
            message: message,
            actionTitle: Consts.Common.OK
        ))
    }
    
    private func updateAccountsAndGetMessage(
        fromAmount: Double,
        toAmount: Double,
        fromIndex: Int,
        toIndex: Int
    ) -> String {
        viewModel.accountItems[fromIndex].amount -= fromAmount
        viewModel.accountItems[toIndex].amount += toAmount
        
        var message: String = .init(
            format: Consts.Scenes.Converter.conversionMessage,
            String(format: "%.2f", fromAmount),
            view.sellCurrency.symbol,
            String(format: "%.2f", toAmount),
            view.receiveCurrency.symbol
        )
        
        if !isFreeConversion {
            let fee: Double = fromAmount * viewModel.commissionPercentage
            viewModel.accountItems[fromIndex].amount -= fee
            message += .init(
                format: Consts.Scenes.Converter.feeMessage,
                String(format: "%.2f", fee), view.sellCurrency.symbol
            )
        }
        
        if isFreeConversion {
            message += .init(
                format: Consts.Scenes.Converter.numberOfFreeExchange,
                viewModel.numberOfFreeExchange - numberOfConversions - 1
            )
        } else {
            message += Consts.Scenes.Converter.noMoreFreeExchange
        }
        
        numberOfConversions += 1
        
        view.setButtonActivity(to: isValidConversion(sellAmount: view.sellAmount, currency: view.sellCurrency))
        view.updateAccountItem(at: fromIndex, viewModel.accountItems[fromIndex])
        view.updateAccountItem(at: toIndex, viewModel.accountItems[toIndex])
        
        return message
    }
}
