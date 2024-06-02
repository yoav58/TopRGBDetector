//
//  Camera.swift
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

import AVFoundation
import UIKit
import SwiftUI

//MARK:  a lot of parts here are from apple developer site apple released a toturial which explain fully how to stream the camera output to the screen.


/// this class is responsible for the camera, it include the camera device and output the stream of the camera
class Camera : NSObject ,ObservableObject {
    
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    @Published var previewStream : AsyncStream<FrameAnalysis>?
    private var previewContinuation : AsyncStream<FrameAnalysis>.Continuation?
    
    override init(){
        super.init()
        previewStream = AsyncStream { continuation in
            self.previewContinuation = continuation
        }

    }
    
    /// this function simply configure our session.
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void){
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        var success = false
        
        defer {
            captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        
        /// deal with input
        guard let captureDevice = AVCaptureDevice.default(for: .video), let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("failed to obtain input")
            return
        }
        
        
        /// deal with output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        
        guard captureSession.canAddInput(deviceInput), captureSession.canAddOutput(videoOutput) else {
            print("failed to add The Input/Output")
            return
        }
        
        /// add the input and output devices
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)


        self.videoOutput = videoOutput
        isCaptureSessionConfigured = true
        captureSession.commitConfiguration()
        success = true
        
    }
    
    /// This function if fully taken from apple site, This function nhecks and requests camera access authorization.
    private func isAuthorized() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Starts the camera stream if authorized and the session is configured.
    func start() async {
        let authorized = await isAuthorized()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async {
                    self.captureSession.startRunning()
                }
            }
            return
        }
        
        sessionQueue.async {
            self.configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    
    
    
}
    
    




/// Extension to handle sample buffer output from the camera. Utilizes the delegate pattern to receive video frames and
/// pass them to the model for further processing. This setup ensures that frame data is continuously updated and available
/// for analysis.
extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Retrieve the pixel buffer containing the image data from the sample buffer.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Create a FrameAnalysis instance to encapsulate the pixel buffer for easier handling in subsequent processing.
        let fr = FrameAnalysis(pixelBuffer: pixelBuffer)
        // Use a task on the main actor to asynchronously pass the frame data for UI updates or further processing.
        Task { @MainActor in
            self.previewContinuation?.yield(fr) /// stream the frame to the model
        }
    }
    
    // MARK: - Debugging Tools

    /// this function is mainly for debug propuse.
    private func printColor(pixelBuffer : CVPixelBuffer){
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        let y = height / 2
        let x = width / 2
                let pixel = buffer + y * bytesPerRow + x * 4 // 4 components per pixel: BGRA
                let blue = pixel.pointee
                let green = pixel.successor().pointee
                let red = pixel.successor().successor().pointee
                print("r : \(red) g: \(green) b \(blue)")
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

    }
    
    /// this function is mainly for debug propuse.
    private func printYuvColor(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let yPlaneBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let uvPlaneBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)


        let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        let x = width / 2
        let y = height / 2

        // Sample Y at the center
        let yIndex = y * yBytesPerRow + x
        let ySample = yPlaneBaseAddress!.assumingMemoryBound(to: UInt8.self)[yIndex]

        // Sample UV at the corresponding center
        let uvIndex = (y / 2) * uvBytesPerRow + (x / 2) * 2
        let uSample = uvPlaneBaseAddress!.assumingMemoryBound(to: UInt8.self)[uvIndex]
        let vSample = uvPlaneBaseAddress!.assumingMemoryBound(to: UInt8.self)[uvIndex + 1]

        print("Y: \(ySample), U: \(uSample), V: \(vSample)")
    }
        
         
}



