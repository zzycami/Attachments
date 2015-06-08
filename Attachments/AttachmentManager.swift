//
//  AttachmentManager.swift
//  Attachments
//
//  Created by damingdan on 15/6/4.
//  Copyright (c) 2015年 kingoit. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import MediaPlayer

@objc public enum AttachmentType:Int{
    case Image
    case Video
    case Audio
    case Screenshot
}

@objc
public protocol AttachmentDelegate:NSObjectProtocol {
    func onAttachmentCreateFinished(attachment:Attachment)
}

public class Attachment:NSObject {
    public var delegate:AttachmentDelegate?
    
    public var image:UIImage?
    
    public var type:AttachmentType = AttachmentType.Image
    
    /// 在获取一些数据的时候可能需要调用一些@c UIViewController， 启动他们需要viewController
    public var viewController:UIViewController?
    
    /// 附件所保存的路径，不一定所有的附件都有存在文件，保存的为相对路径，更目录有 @AttachmentManager决定
    public var file:NSString?
    
    
    public func create() {
    }
}

public class ImageAttachment:Attachment, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public override init() {
        super.init()
        self.type = AttachmentType.Image
    }
    
    private var imagePickerController:UIImagePickerController = UIImagePickerController()
    
    public override func create() {
        var sourceType = UIImagePickerControllerSourceType.Camera
        if !UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        }
        
        imagePickerController.sourceType = sourceType
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        self.viewController?.modalPresentationStyle = UIModalPresentationStyle.CurrentContext
        self.viewController?.presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        self.image = image//editingInfo[UIImagePickerControllerEditedImage] as? UIImage
        delegate?.onAttachmentCreateFinished(self)
        self.viewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func save() {
    }
}


public class VideoAttachment:Attachment, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {
    public override init() {
        super.init()
        self.type = AttachmentType.Video
    }
    
    /// 视屏的时间长度
    public var duration:Double = 0
    
    private var moviePlayerController: MPMoviePlayerController?
    
    private var handler:((Attachment)->Void)?
    private var imagePickerController:UIImagePickerController = UIImagePickerController()
    
    public override func create() {
        var sourceType = UIImagePickerControllerSourceType.Camera
        if !UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            return
        }
        
        imagePickerController.mediaTypes = [kUTTypeMovie]
        imagePickerController.sourceType = sourceType
        imagePickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureMode.Video
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        self.viewController?.modalPresentationStyle = UIModalPresentationStyle.CurrentContext
        self.viewController?.presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        var mediaType = info[UIImagePickerControllerMediaType] as! String
        if mediaType == (kUTTypeMovie as! String) {
            if let  mediaURL = info[UIImagePickerControllerMediaURL] as? NSURL {
                self.movieToImage(mediaURL)
            }
        }
    }
    
    private func movieToImage(url:NSURL) {
        var asset = AVURLAsset.assetWithURL(url) as! AVURLAsset
        self.duration = Double(asset.duration.value) / Double(asset.duration.timescale)
        var generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        var thumbTime = CMTimeMakeWithSeconds(0.2, 30)
        var handler = {(requestedTime:CMTime, im:CGImage!, actualTime:CMTime, result:AVAssetImageGeneratorResult, error:NSError!) -> Void in
            if result == AVAssetImageGeneratorResult.Succeeded {
                var thumbImg = UIImage(CGImage: im)
                self.image = thumbImg
            }
            self.viewController?.dismissViewControllerAnimated(true, completion: nil)
        }
        var value = NSValue(CMTime: thumbTime)
        generator.generateCGImagesAsynchronouslyForTimes([value], completionHandler: handler)
    }
}

public class AudioAttachment:Attachment, AudioViewCotrollerDelegate {
    private var audioViewController:AudioViewCotroller?
    
    public var duration:NSTimeInterval {
        if let controller = self.audioViewController {
            return controller.duration
        }else {
            return 0
        }
    }
    
    public override func create() {
        audioViewController = self.viewController?.storyboard?.instantiateViewControllerWithIdentifier("AudioViewCotroller") as? AudioViewCotroller
        if let controller = self.audioViewController {
            controller.delegate = self
            self.image = UIImage(named: "bg_audio")
            self.viewController?.presentViewController(controller, animated: true, completion: nil)
        }
    }
    
    public func onRecordingFinished(audioViewController: AudioViewCotroller) {
        delegate?.onAttachmentCreateFinished(self)
        self.viewController?.dismissViewControllerAnimated(true, completion: nil)
    }
}

public class AttachmentManager: NSObject, AttachmentDelegate {
    public var attachments:[Attachment] = []
    
    public var onAddAttachment:((AttachmentManager, Attachment)->Void)?
    
    public func getLastAttachment()->Attachment? {
        return attachments.last
    }
    
    public func getFirstAttachment()->Attachment? {
        return attachments.first
    }
    
    public func addAttachment(attachment:Attachment) {
        attachments.append(attachment)
    }
    
    public var viewController:UIViewController?
    
    
    public static func getInstance()->AttachmentManager {
        struct Singleton {
            static var predicate:dispatch_once_t = 0
            static var sharedAttachmentManager:AttachmentManager? = nil
        }
        dispatch_once(&Singleton.predicate, { () -> Void in
            Singleton.sharedAttachmentManager = AttachmentManager()
        })
        return Singleton.sharedAttachmentManager!
    }
    
    /**
    *  附件保存的根路径，由用户设定，默认为空
    */
    public var rootPath:NSString = ""
    
    public func takePhoto() {
        var imageAttachment = ImageAttachment()
        imageAttachment.viewController = self.viewController
        imageAttachment.delegate = self
        imageAttachment.create()
        
    }
    
    public func takeVideo()  {
        var videoAttachment = VideoAttachment()
        videoAttachment.viewController = self.viewController
        videoAttachment.delegate = self
        videoAttachment.create()
    }
    
    public func takeAudio() {
        var audioAttachment = AudioAttachment()
        audioAttachment.viewController = self.viewController
        audioAttachment.delegate = self
        audioAttachment.create()
    }
    
    public func onAttachmentCreateFinished(attachment: Attachment) {
        self.attachments.append(attachment)
        self.onAddAttachment?(self, attachment)
    }
}
