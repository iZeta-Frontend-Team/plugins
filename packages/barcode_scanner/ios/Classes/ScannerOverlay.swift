//
//  ScannerOverlay.swift
//  Runner
//
//  Created by Anh Tai LE on 10/12/2019.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import UIKit

class ScannerOverlay: UIView {

    // Create a scanner line
    lazy var line: UIView = {
        var _line = UIView()
        _line.backgroundColor = .red
        _line.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(_line)
        
        return _line
    }()
    
    // Create a scan Rect
    lazy var scanRect: CGRect = {
        let rect = self.frame
        let heightMultiplier: CGFloat = 0.8
        let scanRectWidth = rect.width * heightMultiplier
        let scanRectHeight = scanRectWidth
        let scanRectOriginX = (rect.width / 2) - (scanRectWidth / 2)
        let scanRectOriginY = (rect.height / 2) - (scanRectHeight / 2)
        
        return CGRect(x: scanRectOriginX, y: scanRectOriginY, width: scanRectWidth, height: scanRectHeight)
    }()
    
    // Create Scan Line Rect
    lazy var scanLineRect: CGRect = {
        let scanRect = self.scanRect
        let rect = self.frame
        
        return CGRect(x: scanRect.origin.x, y: rect.size.height / 2, width: scanRect.size.width, height: 1)
    }()
    
    
    // Draw scan hole + scan line
    override func draw(_ rect: CGRect) {
        
        let context = UIGraphicsGetCurrentContext()
        let overlayColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        
        context?.setFillColor(overlayColor.cgColor)
        context?.fill(self.bounds)
        
        // make a hole for the scanner
        let holeRect = self.scanRect
        let holeRectIntersection = holeRect.intersection(rect)
        UIColor.clear.setFill()
        UIRectFill(holeRectIntersection)
        
        // draw a horizontal line over the middle
        let lineRect = self.scanLineRect
        line.frame = lineRect
        
        // draw the green corners
        let cornerSize: CGFloat = 30
        let path = UIBezierPath()
        
        //top left corner
        path.move(to: CGPoint(x: holeRect.origin.x, y: holeRect.origin.y + cornerSize))
        path.addLine(to: CGPoint(x: holeRect.origin.x, y: holeRect.origin.y))
        path.addLine(to: CGPoint(x: holeRect.origin.x + cornerSize, y: holeRect.origin.y))
        
        //top right corner
        let rightHoleX: CGFloat = holeRect.origin.x + holeRect.width
        path.move(to: CGPoint(x: rightHoleX - cornerSize, y: holeRect.origin.y))
        path.addLine(to: CGPoint(x: rightHoleX, y: holeRect.origin.y))
        path.addLine(to: CGPoint(x: rightHoleX, y: holeRect.origin.y + cornerSize))
        
        // bottom right corner
        let bottomHoleY: CGFloat = holeRect.origin.y + holeRect.height
        path.move(to: CGPoint(x: rightHoleX, y: bottomHoleY - cornerSize))
        path.addLine(to: CGPoint(x: rightHoleX, y: bottomHoleY))
        path.addLine(to: CGPoint(x: rightHoleX - cornerSize, y: bottomHoleY))
        
        // bottom left corner
        path.move(to: CGPoint(x: holeRect.origin.x + cornerSize, y: bottomHoleY))
        path.addLine(to: CGPoint(x: holeRect.origin.x, y: bottomHoleY))
        path.addLine(to: CGPoint(x: holeRect.origin.x, y: bottomHoleY - cornerSize))
        
        path.lineWidth = 2
        UIColor.green.setStroke()
        path.stroke()
        
    }
    
    
    // MARK: Scanning line animation
    
    // Start animation
    func startAnimating() {
        let flash = CABasicAnimation(keyPath: "opacity")
        flash.fromValue = NSNumber(value: 0.0)
        flash.toValue =  NSNumber(value: 1.0)
        flash.duration = 0.25
        flash.autoreverses = true
        flash.repeatCount = HUGE
        line.layer.add(flash, forKey: "flashAnimation")
    }
    
    // Stop animation
    func stopAnimating() {
        self.layer.removeAnimation(forKey: "flashAnimation")
    }
}
