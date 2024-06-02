//
//  RGBDataView.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import SwiftUI

/// this view show the top colors data
struct RGBDataView: View {
    
    var freqColors = [RGBColorFrequency(),RGBColorFrequency(),RGBColorFrequency(),RGBColorFrequency(),RGBColorFrequency()]
    var title = "חלוקת צבעים"
    
    var body: some View {
        
        VStack(spacing: 2){
            Text(self.title)
                .bold()
                .foregroundStyle(.white)
                .padding(.top)
            
            ForEach(freqColors, id: \.self) { freq in
                ColorGuide(color:freq.returnNormColr(),
                           percentage: freq.percentageString,r : freq.rString, g : freq.gString, b : freq.bString)
            }
            
            Spacer()
        }.frame(width:170)
        
            .background(.black)
    }
    
}




#Preview {
    RGBDataView()
}
