//
//  MainViewModel.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import Combine
import SwiftUI



/// i choosed to use mvvm, but  its small project so this view model is not mandatory.
class MainViewModel : ObservableObject {
    
    @Published var  dm : DataModel
    private var cancellables = Set<AnyCancellable>()

    init(){
        dm = DataModel()
        
        // using combine to update changes.
        dm.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
    }
    
    
}
