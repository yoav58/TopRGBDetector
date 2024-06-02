//
//  FrameAnalysis.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import AVFoundation
import UIKit
import SwiftUI

/// this struct help  analysis the the frame pixels, also its a struct so when initialize it with 'let' we can transfar this class between actors.
struct FrameAnalysis{
    
    var pixelBuffer: CVPixelBuffer
    
    
    
    init(pixelBuffer: CVPixelBuffer){
        self.pixelBuffer = pixelBuffer
    }
    
    
    
    /// fhis function simply create the image from the pixels.
    static func createImageFromPixels(_ pixelBuffer: CVPixelBuffer)   -> Image? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage).resizable()
    }
    
    
    /// Analyzes the pixel buffer to find the top five most frequent RGB colors. This method utilizes GPU acceleration
    /// with Metal to efficiently process large amounts of pixel data. It constructs a histogram of color frequencies
    /// using Metal, where each entry in the histogram represents a color and its count within the frame.
    static func findMostFrequentRGB(_ pixelBuffer: CVPixelBuffer) async -> [RGBColorFrequency]? {
        
        guard let metalCompute = MetalCompute() else {
            print("Failed to initialize MetalCompute")
            return nil
        }
        
        /// Using gpu (with metal) to count the number of colors in each frame, the histogram is array of ColorFrequency which contains the color and amount.
        let histogram = metalCompute.process(pixelBuffer: pixelBuffer)
        
        
        /// Here i sorted the array to get the top 5 colors, the sort is fast process since the gpu threads already filtered must of colors that cant be in the top colors, which means this array is quite small.
        let sorted = histogram.sorted{$0.count > $1.count}.prefix(5)
        let totalPixels = CVPixelBufferGetWidth(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
        
        var index = 0
        /// simply create the top 5 colors and return them.
        return sorted.map { c in
            let r = (c.color >> 16) & 0xFF
            let g = (c.color >> 8) & 0xFF
            let b = c.color & 0xFF
            let i = index
            index = index + 1
            return RGBColorFrequency(index: i,r: Double(r), g: Double(g), b: Double(b), percentage: Double(c.count) / Double(totalPixels) * 100)
        }
            
            

            
        }
}
    

        
    
    
    /// small struct that represent color and their count in the frame
    struct ColorFrequency {
        var index: Int
        var count: UInt32
    }
    
    
    


