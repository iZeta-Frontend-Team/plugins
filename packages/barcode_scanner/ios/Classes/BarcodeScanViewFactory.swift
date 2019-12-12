//
//  BarcodeScanViewFactory.swift
//  Runner
//
//  Created by Anh Tai LE on 10/12/2019.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import Flutter
import UIKit
import AVFoundation
import Contacts
import ContactsUI

class FLTBarcodeScanViewFactory: NSObject, FlutterPlatformViewFactory {

    let _messenger: FlutterBinaryMessenger

    init(_ messenger: FlutterBinaryMessenger) {
        self._messenger = messenger
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return FLTBarcodeScanViewController(frame, viewId: viewId, args: args)
    }
}

class FLTBarcodeScanViewController: NSObject, FlutterPlatformView {
    
    let frame: CGRect
    let viewId: Int64
    
    init(_ frame: CGRect, viewId: Int64, args: Any?) {
        self.frame = frame
        self.viewId = viewId
    }
    
    func view() -> UIView {
        let scanView = BarcodeScanView(frame: frame)
        scanView.setupCamera()
        scanView.configScanView()
        
        return scanView
    }
}

class BarcodeScanView: UIView {
    
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    lazy var settingsAlert: AlertCamera = {
        return AlertCamera()
    }()
    var scanRect: CGRect!
    
    // MARK: Setup camera
    
    /// Authorize access to Camera
    func requestAccessToCamera() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            setupCamera()
        } else if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            DispatchQueue.main.async {
                self.openSettingsAlertView()
            }
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                DispatchQueue.main.sync {
                    if granted {
                        self.setupCamera()
                    } else {
                        self.openSettingsAlertView()
                    }
                }
            })
        }
    }
    
    /// Init Capture Session + Scan overlay
    func setupCamera() {
        
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        // Video Input
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            showError()
            return
        }
        
        // MetaOutput
        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showError()
            return
        }
        
        // Video Preview Layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = layer.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(videoPreviewLayer)
        
        // Scanner Overlay
        let scanOverlay = ScannerOverlay(frame: bounds)
        addSubview(scanOverlay)
        scanRect = scanOverlay.frame
        
    }
    
    /// Set area avaiable scanning
    @objc func didChangeCaptureInputPortFormatDescription(notification: NSNotification) {
        if let metadataOutput = captureSession.outputs.last as? AVCaptureMetadataOutput {
            let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: scanRect)
            metadataOutput.rectOfInterest = rect
        }
    }
    
    /// Setting alert to open permission
    func openSettingsAlertView() {
        addSubview(settingsAlert)
        
        // Make constraints
        NSLayoutConstraint.activate([
            settingsAlert.topAnchor.constraint(equalTo: topAnchor),
            settingsAlert.bottomAnchor.constraint(equalTo: bottomAnchor),
            settingsAlert.leadingAnchor.constraint(equalTo: leadingAnchor),
            settingsAlert.trailingAnchor.constraint(equalTo: trailingAnchor)])
        
        // Settings alert buttons
        settingsAlert.doneBtn.setTitle("Go to Settings", for: .normal)
        settingsAlert.doneBtn.addTarget(self, action: #selector(goToSettings), for: .touchUpInside)
    }
    
    /// Go to settings, set permission camera access
    @objc func goToSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in })
            } else {
                // Fallback on earlier versions
                UIApplication.shared.openURL(settingsUrl)
            }
        }
    }
    
    /// Config camera
    func configScanView() {
        // Fixed Scan boundary
        NotificationCenter.default.addObserver(self, selector:#selector(didChangeCaptureInputPortFormatDescription(notification:)), name: .AVCaptureInputPortFormatDescriptionDidChange, object: nil)

        // Start Camera
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }
    
    /// Dispose
    func dispose() {
        // Remove notification
        NotificationCenter.default.removeObserver(self, name: .AVCaptureInputPortFormatDescriptionDidChange, object: nil)
        
        // Stop capture session
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    
    // MARK: Handle error
    func showError() {
        let alertController = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        captureSession = nil
        videoPreviewLayer = nil
        
        // Show alert
        if let rootController = UIApplication.shared.keyWindow?.rootViewController {
            rootController.present(alertController, animated: true)
        }
    }
}

// MARK: Handle AVCapture + Contact delegate
extension BarcodeScanView: AVCaptureMetadataOutputObjectsDelegate, CNContactViewControllerDelegate {
    
    fileprivate func openContactController(_ contact: CNContact) {
        let contactViewController = CNContactViewController(forNewContact: contact)
        contactViewController.contactStore = CNContactStore()
        contactViewController.delegate = self
        
        contactViewController.shouldShowLinkedContacts = true
                                                    
        contactViewController.view.layoutIfNeeded()
        let navigationController = UINavigationController(rootViewController: contactViewController)
        
        // Show Contact application
        if let rootController = UIApplication.shared.keyWindow?.rootViewController {
            rootController.present(navigationController, animated: true)
        }
    }
    
    /// Scan QRCode output handling
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count > 0, let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
           object.type == AVMetadataObject.ObjectType.qr {
            
            guard let value = object.stringValue else { return }
            
            // Stop camera
            captureSession.stopRunning()
            
            // Make read content
            if value.contains("BEGIN:VCARD") {
                guard let data = value.data(using: .utf8) else { return }
                
                do {
                    let contacts: [CNContact] = try CNContactVCardSerialization.contacts(with: data)
                    if let contact = contacts.first {
                        DispatchQueue.main.async {
                            self.openContactController(contact)
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                    // MARK: Make result error here
                }
            } else {
                // MARK: Show QRCode content
            }
        }
    }
    
    /// Contact Controller Handling
    func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
        return true
    }
    
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        viewController.dismiss(animated: true, completion: nil)
    }
}
