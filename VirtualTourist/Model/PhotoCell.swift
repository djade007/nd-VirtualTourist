//
//  PhotoCell.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import UIKit

import CoreData

class PhotoCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
    
    func downloadPhoto(for photoInfo: PhotoInfo, pin: Pin) {
        ApiClient.downloadPhoto(photoInfo: photoInfo) { (data, error) in
            guard let data = data else { return }
            
            self.savePhoto(pin: pin, photoData: data)
            self.imageView.image = UIImage(data: data)
            DataModel.photosData.append(data)
        }
    }
    
    
    private func savePhoto(pin: Pin, photoData: Data) {
        let viewContext = DataController.shared.backgroundContext
        
        let pin = viewContext.object(with: pin.objectID) as! Pin
        
        viewContext.perform {
            let photo = Photo(context: viewContext)
            photo.pin = pin
            photo.data = photoData
            photo.createdAt = Date()
            try? viewContext.save()
        }
    }
}
