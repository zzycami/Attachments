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


public class ImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet var overlayView: UIView!
    
    public var delegate:UIImagePickerControllerDelegate?
    
    private var imagePickerController:UIImagePickerController?
    
    private weak var viewController:UIViewController?
    
    private var isTakingVideo:Bool = false
    
    public init(delegate:UIImagePickerControllerDelegate) {
        super.init()
        self.delegate = delegate
    }
    
    public func showPickerOnViewController(viewController:UIViewController) {
        if !UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            return
        }
        imagePickerController = UIImagePickerController()
        imagePickerController!.allowsEditing = false
        imagePickerController!.modalPresentationStyle = UIModalPresentationStyle.FullScreen
        imagePickerController!.sourceType = UIImagePickerControllerSourceType.Camera
        imagePickerController!.cameraFlashMode = UIImagePickerControllerCameraFlashMode.Off
        imagePickerController?.delegate = self
        
        imagePickerController?.showsCameraControls = false
        NSBundle.mainBundle().loadNibNamed("Overlay", owner: self, options: nil)
        self.overlayView.frame = imagePickerController!.cameraOverlayView!.frame
        imagePickerController!.cameraOverlayView = self.overlayView
        
        self.viewController = viewController
        viewController.presentViewController(imagePickerController!, animated: true, completion: nil)
    }
    
    public func takeVideoOnViewController(viewController:UIViewController) {
        var sourceType = UIImagePickerControllerSourceType.Camera
        if !UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            return
        }
        imagePickerController = UIImagePickerController()
        imagePickerController!.mediaTypes = [kUTTypeMovie]
        imagePickerController!.sourceType = sourceType
        imagePickerController!.cameraCaptureMode = UIImagePickerControllerCameraCaptureMode.Video
        imagePickerController!.delegate = self
        imagePickerController!.allowsEditing = true
        self.viewController?.modalPresentationStyle = UIModalPresentationStyle.FullScreen
        
        imagePickerController?.showsCameraControls = false
        NSBundle.mainBundle().loadNibNamed("Overlay", owner: self, options: nil)
        self.overlayView.frame = imagePickerController!.cameraOverlayView!.frame
        imagePickerController!.cameraOverlayView = self.overlayView
        
        isTakingVideo = false
        
        self.viewController = viewController
        viewController.presentViewController(imagePickerController!, animated: true, completion: nil)
    }
    
    private func setFullScreen() {
        //Based on http://stackoverflow.com/a/20228332/281461
        var screenBounds = UIScreen.mainScreen().bounds.size
        var cameraAspectRatio:CGFloat = 4.0/3.0

        var camViewHeight = screenBounds.width * cameraAspectRatio
        var scale = screenBounds.height / camViewHeight
        imagePickerController!.cameraViewTransform = CGAffineTransformMakeTranslation(0, (screenBounds.height - camViewHeight) / 2.0)
        imagePickerController!.cameraViewTransform = CGAffineTransformScale(imagePickerController!.cameraViewTransform, scale, scale)
    }
    
    @IBAction func capture(sender: AnyObject) {
        if imagePickerController?.cameraCaptureMode == UIImagePickerControllerCameraCaptureMode.Video {
            if isTakingVideo {
                self.imagePickerController?.stopVideoCapture()
            }else {
                self.imagePickerController?.startVideoCapture()
            }
        }else {
            self.imagePickerController?.takePicture()
        }
        
    }
    
    @IBAction func toggleFlash(sender: AnyObject) {
        if imagePickerController?.cameraFlashMode == UIImagePickerControllerCameraFlashMode.Off {
            if UIImagePickerController.isFlashAvailableForCameraDevice(imagePickerController!.cameraDevice) {
                imagePickerController?.cameraFlashMode = UIImagePickerControllerCameraFlashMode.On
                flashButton.selected = true
            }
        }else {
            imagePickerController?.cameraFlashMode = UIImagePickerControllerCameraFlashMode.Off
            flashButton.selected = false
        }
        
    }
    
    @IBAction func flipCamera(sender: AnyObject) {
        if self.imagePickerController?.cameraDevice == UIImagePickerControllerCameraDevice.Front {
            if UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) {
                imagePickerController?.cameraDevice = UIImagePickerControllerCameraDevice.Rear
            }
        }else {
            if UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front) {
                if !UIImagePickerController.isFlashAvailableForCameraDevice(UIImagePickerControllerCameraDevice.Front) {
                    self.flashButton.selected = false
                    imagePickerController?.cameraFlashMode = UIImagePickerControllerCameraFlashMode.Off
                }
                imagePickerController?.cameraDevice = UIImagePickerControllerCameraDevice.Front
            }
        }
    }
    
    @IBAction func dismiss(sender: AnyObject) {
        if let imagePickerController = self.imagePickerController {
            delegate?.imagePickerControllerDidCancel?(imagePickerController)
        }
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if let imagePickerController = self.imagePickerController {
            delegate?.imagePickerController?(picker, didFinishPickingMediaWithInfo: info)
        }
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        if let imagePickerController = self.imagePickerController {
            delegate?.imagePickerControllerDidCancel?(imagePickerController)
        }
    }
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

public class ImageAttachment:Attachment, UIImagePickerControllerDelegate {
    public override init() {
        super.init()
        self.type = AttachmentType.Image
    }
    
    private var imagePicker:ImagePicker?
    
    public override func create() {
        if let viewController = self.viewController {
            imagePicker = ImagePicker(delegate: self)
            imagePicker!.showPickerOnViewController(viewController)
        }
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        self.image = info[UIImagePickerControllerOriginalImage] as? UIImage
        delegate?.onAttachmentCreateFinished(self)
        self.viewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        println("image did cancel")
        self.viewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func save() {
    }
}


public class VideoAttachment:Attachment, UIImagePickerControllerDelegate  {
    public override init() {
        super.init()
        self.type = AttachmentType.Video
    }
    
    /// 视屏的时间长度
    public var duration:Double = 0
    
    private var imagePicker:ImagePicker?
    
    private var handler:((Attachment)->Void)?
    private var imagePickerController:UIImagePickerController = UIImagePickerController()
    
    public override func create() {
        if let viewController = self.viewController {
            imagePicker = ImagePicker(delegate: self)
            imagePicker!.takeVideoOnViewController(viewController)
        }
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        var mediaType = info[UIImagePickerControllerMediaType] as! String
        if mediaType == (kUTTypeMovie as! String) {
            if let  mediaURL = info[UIImagePickerControllerMediaURL] as? NSURL {
                self.movieToImage(mediaURL)
            }
        }
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        println("image did cancel")
        self.viewController?.dismissViewControllerAnimated(true, completion: nil)
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
                self.delegate?.onAttachmentCreateFinished(self)
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
