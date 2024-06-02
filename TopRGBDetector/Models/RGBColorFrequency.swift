//
//  RGBColorFrequency.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import Foundation
import SwiftUI


/// This Struct Represents a color frequently appearing in the camera feed. This struct includes RGB values,
/// the count of occurrences, and the percentage of the total analyzed colors.
struct RGBColorFrequency : Hashable{
    var index = 0
    var r : Double = 0
    var g : Double = 0
    var b : Double = 0
    var count : UInt32 = 0
    var percentage : Double = 0
    
    var rString : String {
        return String(r)
    }
    
    var gString : String {
        return String(g)
    }
    
    var bString : String {
        return String(b)
    }
    
    var percentageString : String {
        return String(format: "%.2f",percentage)
    }
    
    func returnColor() -> UIColor{
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    func returnNormColr() -> Color {
        return  Color(red: Double(Int(r)) / 256, green: Double(Int(g)) / 256, blue: Double(Int(b)) / 256, opacity: 1)
    }
    
}
