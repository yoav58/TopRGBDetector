//
//  FrameView.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import SwiftUI


struct FrameView: View {
    var image : Image?
    private let label = Text("Frame")
    var body: some View {
        
        ZStack{
            Color.gray
            if let image {
                image
            }
        }.ignoresSafeArea()
        
    }
}

#Preview {
    FrameView()
}
