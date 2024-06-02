//
//  ContentView.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import SwiftUI

struct MainView: View {
    
    @StateObject var vm = MainViewModel()

    var body: some View {
        ZStack{
            Color(.black)
            HStack(spacing: 0){
                FrameView(image: vm.dm.currentFrame)
                Spacer()
                RGBDataView(freqColors: vm.dm.topRgb ?? [])

            }

        }.ignoresSafeArea()

    }
}

#Preview {
    MainView()
}
