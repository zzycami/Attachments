//
//  AttachmentViewController.swift
//  Attachments
//
//  Created by damingdan on 15/6/4.
//  Copyright (c) 2015年 kingoit. All rights reserved.
//

import UIKit

class AttachmentCell:UICollectionViewCell {
    @IBOutlet weak var imageView:UIImageView!
    
    @IBOutlet weak var infoContainerView:UIView!
    
    @IBOutlet weak var iconImageView:UIImageView!
    
    @IBOutlet weak var infoLabel:UILabel!
    
    func configCell(attachment:Attachment) {
        if attachment.isKindOfClass(ImageAttachment) {
            if let att = attachment as? ImageAttachment {
                imageView.image = att.image
                infoContainerView.hidden = true
            }
        }else if attachment.isKindOfClass(VideoAttachment) {
            if let att = attachment as? VideoAttachment {
                var length = String(format: "%.2f", arguments: [att.duration])
                infoLabel.text = length
                iconImageView.image = UIImage(named: "icon_video")
                infoContainerView.hidden = false
                imageView.image = att.image
            }
        }else if attachment.isKindOfClass(AudioAttachment) {
            if let att = attachment as? AudioAttachment {
                var length = String(format: "%.2f", arguments: [att.duration])
                infoLabel.text = length
                iconImageView.image = UIImage(named: "icon_music")
                infoContainerView.hidden = false
                imageView.image = att.image
            }
        }
    }
}

class AttachmentViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var manager:AttachmentManager = AttachmentManager.getInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        
        self.manager.onAddAttachment = {(manager:AttachmentManager, attachment:Attachment)->Void in
            self.collectionView.reloadData()
        }
    }

    @IBAction func recoredWave(sender: AnyObject) {
        self.manager.viewController = self
        self.manager.takeAudio()
    }
    
    @IBAction func takeVideo(sender: AnyObject) {
        self.manager.viewController = self
        self.manager.takeVideo()
    }
    
    @IBAction func takeScreenshoot(sender: AnyObject) {
    }
    
    @IBAction func takePhoto(sender: AnyObject) {
        self.manager.viewController = self
        self.manager.takePhoto()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.manager.attachments.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell = collectionView.dequeueReusableCellWithReuseIdentifier("AttachmentCell", forIndexPath: indexPath) as! AttachmentCell
        cell.configCell(self.manager.attachments[indexPath.row])
        return cell
    }
}
