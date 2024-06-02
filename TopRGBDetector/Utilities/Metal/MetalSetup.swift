//
//  MetalSetup.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//


import Foundation
import Metal
import MetalKit


/// this class is singelton class, it represent the gpu and its commandQueue. 
class MetalSetup {
    static let shared = MetalSetup()
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    private init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Failed to Found the default device")
            return nil
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue
    }
}
