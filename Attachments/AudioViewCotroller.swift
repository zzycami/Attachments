//
//  AudioViewCotroller.swift
//  Attachments
//
//  Created by damingdan on 15/6/7.
//  Copyright (c) 2015年 kingoit. All rights reserved.
//

import UIKit
import AVFoundation

@objc
public protocol AudioViewCotrollerDelegate:NSObjectProtocol {
    optional func onRecordingInitFailed(audioViewController:AudioViewCotroller, error:NSError)
    optional func onRecordingParepareFailed(audioViewController:AudioViewCotroller)
    optional func onRecordingFailed(audioViewController:AudioViewCotroller)
    
    optional func onRecordingFinished(audioViewController:AudioViewCotroller)
}

public class AudioViewCotroller: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @IBOutlet weak var recordingTimeLabel: TimerLabel!
    @IBOutlet weak var recordingSoundImageView: UIImageView!
    @IBOutlet weak var recordingStartButton: UIButton!
    @IBOutlet weak var recordingEndButton: UIButton!
    
    public var delegate:AudioViewCotrollerDelegate?
    
    public var duration:NSTimeInterval {
        if let p = self.player {
            return p.duration
        }else {
            return 0
        }
    }
    
    private var recorder:AVAudioRecorder!
    private var player:AVAudioPlayer?
    
    public var recordSetting:[NSString:NSObject] {
        var setting = [NSString:NSObject]()
        setting[AVFormatIDKey] = NSNumber(integer: kAudioFormatAppleIMA4)
        setting[AVSampleRateKey] = NSNumber(float: 44110)
        setting[AVNumberOfChannelsKey] = NSNumber(integer: 2)
        
        //Linear PCM Format Settings (only necessary when you want to record Liner PCM format)
        setting[AVLinearPCMBitDepthKey] = NSNumber(integer: 32)
        setting[AVLinearPCMIsBigEndianKey] = NSNumber(bool: false)
        setting[AVLinearPCMIsFloatKey] = NSNumber(bool: false)
        
        //Encoder Settings (Only necessary if you want to change it.)
        setting[AVEncoderAudioQualityKey] = NSNumber(integer: AVAudioQuality.Medium.rawValue)
        setting[AVEncoderBitRateKey] = NSNumber(integer: 96)
        setting[AVEncoderBitDepthHintKey] = NSNumber(integer: 16)
        
        //Sample Rate Conversion Settings (Only necessary when you want to change the sample rate to a value different to the hardware sample rate, AVAudioQualityHigh means no conversion, usually, 44.1KHz)
        setting[AVSampleRateConverterAudioQualityKey] = NSNumber(integer: AVAudioQuality.High.rawValue)
        
        return setting
    }
    
    private var url:NSURL!
    
    // MARK:- Life Cycle
    public override func  viewDidLoad() {
        super.viewDidLoad()
        
        // Init audio
        initRecord()
        initAnimation()
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.requestRecordPermission()
    }
    
    
    deinit {
        
    }
    
    //MARK: System Delegate
    public func audioRecorderDidFinishRecording(recorder: AVAudioRecorder!, successfully flag: Bool) {
        println("record finish:\(flag)")
    }
    
    public func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder!, error: NSError!) {
        println("record error:\(error)")
    }
    
    public func audioRecorderBeginInterruption(recorder: AVAudioRecorder!) {
        println("record begin interrupt")
    }
    
    public func audioRecorderEndInterruption(recorder: AVAudioRecorder!) {
        println("record end interrupt")
    }
    
    public func audioRecorderEndInterruption(recorder: AVAudioRecorder!, withFlags flags: Int) {
        println("record end interrupt\(flags)")
    }
    
    public func audioRecorderEndInterruption(recorder: AVAudioRecorder!, withOptions flags: Int) {
        println("record end interrupt\(flags)")
    }
    
    
    // MARK:- Event Response
    @IBAction func onRecordingStart(sender: UIButton) {
        if prepareRecord() {
            if recorder.recording {
                return
            }
            println(recorder.url)
            var ret = recorder.record()
            if !ret {
                println("record failed")
                delegate?.onRecordingFailed?(self)
                return
            }
            println("\(recorder.recording)")
            startAnimation()
            recordingTimeLabel.start()
        }
    }
    
    @IBAction func onRecordingStop(sender: UIButton) {
        if !recorder.recording {
            return
        }
        println("\(recorder.recording)")
        recorder.stop()
        recordingTimeLabel.pause()
        recordingTimeLabel.reset()
        stopAnimation()
        preparePlayer()
        delegate?.onRecordingFinished?(self)
    }
    
    // MARK:- Private Method
    private func initRecord() {
        var formater = NSDateFormatter()
        formater.dateFormat = "yyyyMMddHHmmss"
        var filename = formater.stringFromDate(NSDate())
        filename = filename.stringByAppendingPathExtension("caf")!
        var document = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as! String
        var filePath = document.stringByAppendingPathComponent(filename)
        self.url = NSURL(fileURLWithPath: filePath)
        var error:NSError?
        recorder = AVAudioRecorder(URL: url, settings: self.recordSetting, error: &error)
        if error != nil {
            println("init failed \(error)")
            self.delegate?.onRecordingInitFailed?(self, error: error!)
        }
        recorder.delegate = self
    }
    
    private func prepareRecord()->Bool {
        var ret = recorder.prepareToRecord()
        if !ret {
            println("prepare faield")
            self.delegate?.onRecordingParepareFailed?(self)
            return false
        }
        return true
    }
    
    private func preparePlayer() {
        var error:NSError?
        player = AVAudioPlayer(contentsOfURL: self.url, error: &error)
        if error != nil {
            println(error)
        }
        player?.delegate = self
    }
    
    private func initAnimation() {
        if recordingSoundImageView.isAnimating() {
            return
        }
        var frames:[UIImage] = []
        for i in 1...4 {
            frames.append(UIImage(named: "record_sound\(i)")!)
        }
        recordingSoundImageView.animationImages = frames
        recordingSoundImageView.animationRepeatCount = 0
        recordingSoundImageView.animationDuration = 1
    }
    
    private func startAnimation() {
        self.recordingSoundImageView.startAnimating()
    }
    
    private func stopAnimation() {
        self.recordingSoundImageView.stopAnimating()
    }
    
    private func requestRecordPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { (granted:Bool) -> Void in
            if granted {
                self.recordingStartButton.enabled = true
                self.recordingEndButton.enabled = true
            }else {
                self.recordingStartButton.enabled = false
                self.recordingEndButton.enabled = false
            }
        }
        
        //[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        var error:NSError?
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, error: &error)
        if error != nil {
            println("\(error)")
        }
    }
    
    // MARK:- Public Method
}
