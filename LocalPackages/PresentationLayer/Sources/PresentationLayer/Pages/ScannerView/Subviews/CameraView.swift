//
// CameraView.swift
// Proton Authenticator - Created on 07/08/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Authenticator.
//
// Proton Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

#if os(iOS)
@preconcurrency import AVFoundation
@preconcurrency import Combine
import SwiftUI

public protocol CameraManagerProtocol: Actor {
    nonisolated var session: AVCaptureSession { get }
    nonisolated var isTakingPhoto: CurrentValueSubject<Bool, Never> { get }
    nonisolated var takenPhoto: PassthroughSubject<AVCapturePhoto?, Never> { get }

    func setUpSession() throws
    func startSession()
    func stopSession()
    func takePhoto() throws
}

private class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

public actor CameraManager: NSObject, /*@unchecked Sendable,*/ CameraManagerProtocol {
    public nonisolated let session = AVCaptureSession()
    private var setUp = false
    private let photoOutput = AVCapturePhotoOutput()

    public let isTakingPhoto = CurrentValueSubject<Bool, Never>(false)
    public nonisolated let takenPhoto = PassthroughSubject<AVCapturePhoto?, Never>()

    enum CameraError: Error, CustomDebugStringConvertible {
        case noDevices
        case pendingPhotoTaking

        var debugDescription: String {
            switch self {
            case .noDevices:
                "No devices"
            case .pendingPhotoTaking:
                "Pending photo taking"
            }
        }
    }

    deinit {
        print("\(Self.self) is deinit")
    }

    override init() {
        super.init()
        print("\(Self.self) is initialized")
    }

    public func setUpSession() throws {
        guard !setUp else { return }
        defer { setUp = true }

        let discoverySession =
            AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                             mediaType: .video,
                                             position: .back)
        guard let device = discoverySession.devices.first else {
            throw CameraError.noDevices
        }

        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        session.sessionPreset = .photo

        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    public func startSession() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    public func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    public func takePhoto() throws {
        if isTakingPhoto.value {
            throw CameraError.pendingPhotoTaking
        }
        isTakingPhoto.send(true)
        photoOutput.capturePhoto(with: .init(), delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    public nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                        didFinishProcessingPhoto photo: AVCapturePhoto,
                                        error: (any Error)?) {
        takenPhoto.send(photo)
        isTakingPhoto.send(false)
    }
}

#endif
