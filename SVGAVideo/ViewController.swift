//
//  ViewController.swift
//  SVGAVideo
//
//  Created by lvpengwei on 7/20/18.
//  Copyright © 2018 lvpengwei. All rights reserved.
//

import UIKit
import SVGAPlayer
import SCRecorder
import AVFoundation
import Photos

class ViewController: UIViewController {
    private var exportSession: SCAssetExportSession?
    @IBAction func tapAction(_ sender: Any) {
        exportSession?.cancelExport()
        loadSticker { [weak self] (sticker) in
            guard let s = self else { return }
            s.export(sticker)
        }
    }
    private var parse = SVGAParser()
    private func loadSticker(_ completion: @escaping ((SVGAPlayer) -> Void)) {
        guard let path = Bundle.main.path(forResource: "rose_2.0.0", ofType: "svga") else { return }
        let url = URL(fileURLWithPath: path)
        parse.parse(with: url, completionBlock: { (videoEntity) in
            guard let videoEntity = videoEntity else { return }
            let sticker = SVGAPlayer()
            sticker.videoItem = videoEntity
            completion(sticker)
        }) { (err) in
            guard let err = err else { return } 
            print("parse sticker: \(err.localizedDescription)")
        }
    }
    private func export(_ sticker: SVGAPlayer) {
        guard let path = Bundle.main.path(forResource: "1532072337.63853", ofType: "MP4") else { return }
        let asset = AVAsset(url: URL(fileURLWithPath: path))
        sticker.timeRange = CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))
        exportSession = SCAssetExportSession(asset: asset)
        exportSession?.delegate = self
        exportSession?.videoConfiguration.overlay = sticker
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory() + "/\(Date().timeIntervalSince1970).mp4")
        exportSession?.outputUrl = outputURL
        exportSession?.outputFileType = AVFileType.mp4.rawValue

        exportSession?.exportAsynchronously(completionHandler: { [weak self] in
            guard let s = self else { return }
            if let err = s.exportSession?.error {
                print(err.localizedDescription)
            } else {
                print("complete")
                s.saveVideoToAlbum(outputURL, nil)
            }
        })
    }
    private func requestAuthorization(completion: @escaping ()->Void) {
        if PHPhotoLibrary.authorizationStatus() == .notDetermined {
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else if PHPhotoLibrary.authorizationStatus() == .authorized {
            completion()
        }
    }
    private func saveVideoToAlbum(_ outputURL: URL, _ completion: ((Error?) -> Void)?) {
        requestAuthorization {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: outputURL, options: nil)
            }) { (result, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print(error.localizedDescription)
                    } else {
                        print("保存成功")
                    }
                    completion?(error)
                }
            }
        }
    }
}

extension ViewController: SCAssetExportSessionDelegate {
    func assetExportSessionDidProgress(_ assetExportSession: SCAssetExportSession) {
        print("progress: \(assetExportSession.progress)")
    }
}

extension SVGAPlayer: SCVideoOverlay {
    static var timeRangeKey = "time_range_key"
    var timeRange: CMTimeRange {
        get {
            return (objc_getAssociatedObject(self, &SVGAPlayer.timeRangeKey) as? CMTimeRange) ?? kCMTimeRangeZero
        }
        set {
            objc_setAssociatedObject(self, &SVGAPlayer.timeRangeKey, newValue as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    public func update(withVideoTime time: TimeInterval) {
        let percent = (time - timeRange.start.seconds) / timeRange.duration.seconds
        guard percent >= 0 && percent <= 1 else {
            isHidden = true
            return
        }
        isHidden = false
        step(toPercentage: CGFloat(percent), andPlay: false)
    }
}
