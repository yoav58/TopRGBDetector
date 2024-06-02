//
//  ColorGuide.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import SwiftUI

// This view is to show the data on the color.
struct ColorGuide : View{
    
    var color : Color = .white
    var percentage : String = "0.00"
    var r = "0"
    var g = "0"
    var b = "0"
    
    
    var body: some View{
        
        VStack{
            Rectangle()
                .foregroundColor(color)
                .frame(width: 80,height: 40)
                .overlay{
                    Text(percentage + "%")
                        .foregroundStyle(.white)
                        .shadow(color: .black,radius: 1)
                }
            HStack(spacing: 10){
                Text("R \(r)").font(.system(size: 8))
                Text("G \(g)").font(.system(size: 8))
                Text("B \(b)").font(.system(size: 8))

            }.foregroundColor(.white)
        }
    }
    
}

#Preview {
    ColorGuide()
}
