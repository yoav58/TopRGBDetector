//
//  MetalCompute.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import Metal
import MetalKit

//MARK: in this file of code i used a lot of help from chatGpt, and from the video "Explain me Metal like I'm 5 - iOS Conf SG 2020"

/// This class serves as a bridge between Swift and Metal, providing a simplified API to perform GPU-based operations.
/// It manages the lifecycle of Metal objects and executes specific compute tasks on the GPU.
class MetalCompute {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipeline: MTLComputePipelineState
    
    init?() {
        
        // init the device and MTLCommandQueue.
        guard let device = MetalSetup.shared?.device,
              let commandQueue = MetalSetup.shared?.commandQueue else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        
        // init the pipeline state
        let library = device.makeDefaultLibrary()
        let kernel = library?.makeFunction(name: "computeYuvToRgb")
        
        do {
            computePipeline = try device.makeComputePipelineState(function: kernel!)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
            return nil
        }
    }
    
    /// this function is responsibe to invoke the gpu methods, it does 2 things:
    /// 1) using metal function "computeYuvToRgb" to count the amount of each color.
    /// 2) doing reduction with the function "findLocalTopColors"
    func process(pixelBuffer: CVPixelBuffer) -> [ColorCount] {
        
        // Locks the base address of the pixel buffer.
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        /// For the Y component (luma) and two chroma components U and V r create texture that represent them.
        let yTexture = createTexture(from: pixelBuffer, planeIndex: 0, pixelFormat: .r8Unorm)
        let uvTexture = createTexture(from: pixelBuffer, planeIndex: 1, pixelFormat: .rg8Unorm)
        
        guard let yTexture = yTexture, let uvTexture = uvTexture else {
            print("Failed to create textures")
            return []
        }
        
        /// create the histogram and initiliza all the values to zero
        let histogramSize = 256 * 256 * 256
        var histogram = [UInt32](repeating: 0, count: histogramSize)
        
        guard let histogramBuffer = device.makeBuffer(bytes: &histogram, length: histogramSize * MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            print("Failed to create histogram buffer")
            return []
        }
        
        // start set the Command Encoder, set the buffer place, texture place and number of threads..
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setTexture(yTexture, index: 0)
        computeEncoder.setTexture(uvTexture, index: 1)

        computeEncoder.setBuffer(histogramBuffer, offset: 0, index: 0) // Bind the histogram buffer to slot 0
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(width: (yTexture.width + 15) / 16, height: (yTexture.height + 15) / 16, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        

        
        //MARK: - start the second gpu operetion ("findLocalTopColors").
        
        
        let topFiveFunction = device.makeDefaultLibrary()?.makeFunction(name: "findLocalTopColors")
        guard let topFiveFunction = topFiveFunction, let topFivePipeline = try? device.makeComputePipelineState(function: topFiveFunction) else {
            return []
        }
        let topFiveEncoder = commandBuffer.makeComputeCommandEncoder()!
        topFiveEncoder.setComputePipelineState(topFivePipeline)
        topFiveEncoder.setBuffer(histogramBuffer, offset: 0, index: 0)
        
        /// i used reduceFactor to adjust the number of threads,
        let reduceFactor = 256
        let topFiveThreadGroupSize = MTLSize(width: 256, height: 1, depth: 1)
        let topFiveThreadGroups = MTLSize(width: histogramSize / (256 * reduceFactor), height: 1, depth: 1)
        
        
        
        // set top 5 color buffer
        
        let numberOfTopColors = 5;
        // calculate total thread
        let totalThreads = topFiveThreadGroupSize.width * topFiveThreadGroups.width
        // the global color buffer size should be total totalThreads * numberOfTopColors since each thread has its own top five colors.
        let topColorsCount = totalThreads * numberOfTopColors;
        var globalTopColors = [ColorCount](repeating: ColorCount(color: 0, count: 0), count: topColorsCount)
        
        guard let globalTopColorsBuffer = device.makeBuffer(bytes: &globalTopColors, length: globalTopColors.count * MemoryLayout<ColorCount>.size, options: .storageModeShared) else {
            print("Failed to create global top colors buffer")
            return []
        }
        topFiveEncoder.setBuffer(globalTopColorsBuffer, offset: 0, index: 1)
        
        
        // set the seg size of each thread;
        var segmentSize =  256 * 256 * 256 / totalThreads
        let segmentSizeBuffer = device.makeBuffer(bytes: &segmentSize, length: MemoryLayout<UInt32>.size, options: .storageModeShared)!
        topFiveEncoder.setBuffer(segmentSizeBuffer, offset: 0, index: 2)
        
        topFiveEncoder.dispatchThreadgroups(topFiveThreadGroups, threadsPerThreadgroup: topFiveThreadGroupSize)
        
        
        topFiveEncoder.endEncoding()
        // send the commands to the commandQueue.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // get the result from the buffer and convert to array
        let topColorsData = globalTopColorsBuffer.contents().bindMemory(to: ColorCount.self, capacity: topColorsCount)
        let topColorsArray = Array(UnsafeBufferPointer(start: topColorsData, count: topColorsCount))
        return topColorsArray
    }
    
    
    /// helping method to create Texture, since Y and UV has their own texture i avoid code Recycle
    private func createTexture(from pixelBuffer: CVPixelBuffer, planeIndex: Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        var texture: MTLTexture?
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        
        let textureRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        if let textureRef = textureRef {
            texture = device.makeTexture(descriptor: textureDescriptor, iosurface: textureRef, plane: planeIndex)
        }
        
        return texture
    }
    
    

    

}



struct ColorCount {
    let color : UInt32
    let count : UInt32
};
