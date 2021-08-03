//
//  PhotoViewerController.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import UIKit

class PhotoViewerController: UIViewController {
    var photo: Data!
       
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = UIImage(data: photo)
    }
}
