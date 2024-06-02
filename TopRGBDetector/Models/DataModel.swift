//
//  DataModel.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import SwiftUI
import AVFoundation


/// Manages the data related to the camera stream, including current frame images and the analysis of the top RGB colors.
/// This class interacts with the `Camera` to start the stream and handles the updates of both the frame and color analysis.

final class DataModel: ObservableObject {
    let camera = Camera()
    @Published var currentFrame: Image?
    @Published var topRgb : [RGBColorFrequency]?
    init() {
        Task {
            await camera.start()
            await handleCameraPreviews()
        }
    }
    /// Continuously processes frames from the camera's preview stream to update `currentFrame` and `topRgb`.
    func handleCameraPreviews() async {
        
        guard camera.previewStream != nil else {
            print("Preview stream is not available.")
            return
        }
        
        /// Asynchronously processes each frame from the camera's preview stream. This function performs two main tasks:
        /// 1) Creating an image from frame pixels and updating the UI with the new image.
        /// 2) Analyzing the frame to find the most frequent RGB colors and updating the UI with these colors.
        for await frame in camera.previewStream! {
            
            Task{
                let image = FrameAnalysis.createImageFromPixels(frame.pixelBuffer)
                await MainActor.run {
                    currentFrame = image
                }
            }
                Task{
                    let trgb = await FrameAnalysis.findMostFrequentRGB(frame.pixelBuffer)
                    
                    await MainActor.run {
                        topRgb = trgb
                    }
                }
            }
        }
    }
    
