//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    
    // MARK: Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var noPhotosFoundLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    // MARK: Properties
    
    var pin: Pin!
    var selectedLocation: CLLocation!
    
    private var shouldDownload = true
    private var photosInfo = [PhotoInfo]()
    private var blockOperations = [BlockOperation]()
    private var fetchedResultsController: NSFetchedResultsController<Photo>!
    
    var dataController: DataController {
        return DataController.shared
    }
    
    
    // MARK: LifeCycles
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        
        setupCollectionView()
        setupFlowLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupData()
        
        setCenterRegion(coordinate: selectedLocation.coordinate)
        addPin(coordinate: selectedLocation.coordinate)
    }
    
    
    
    @IBAction func unwindToMain(segue: UIStoryboardSegue){
           
    }
    
    //  MARK: Initialization Functions
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func setupFlowLayout() {
        flowLayout.minimumLineSpacing = 1.0
        flowLayout.minimumInteritemSpacing = 1.0
    }
    
    private func setupData() {
        startLoading(true)
        shouldDownload = pin.photos?.count ?? 0 <= 0
        DataModel.photosData = []
       
        if shouldDownload {
            fetchPhotos(coordinate: selectedLocation.coordinate)
        } else {
            setupFetchedResultsController()
            let photos = fetchedResultsController.fetchedObjects ?? []
            DataModel.photosData = photos.map { $0.data! }
            startLoading(false)
        }
    }
    
    
    
    
    // MARK: Button Related Functions
    

    @IBAction func newCollectionButtonPressed(_ sender: Any) {
        
        fetchedResultsController = nil
        DataModel.photosData = []
        photosInfo = []
        
        collectionView.reloadData()
        
        let context = DataController.shared.viewContext
        
        context.performAndWait {
            let pinToDeletePhotos = context.object(with: self.pin.objectID) as! Pin
            pinToDeletePhotos.photos = []
            try? context.save()
        }
        
        setupData()
    }
    
    private func setDownloadingState(isDownloading: Bool) {
        newCollectionButton.isEnabled = !isDownloading
        if isDownloading {
            newCollectionButton.title = "Downloading..."
        } else {
            newCollectionButton.title = "New Collection"
        }
        
    }
    
    private func startLoading(_ loading: Bool) {
        if loading {
            noPhotosFoundLabel.isHidden = true
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    
    
    // MARK: Map Related Functions
    
    private func setCenterRegion(coordinate: CLLocationCoordinate2D) {
        let distance: CLLocationDistance = 100000.0
        let coordinate2D = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let region = MKCoordinateRegion(center: coordinate2D, latitudinalMeters: distance, longitudinalMeters: distance)
        mapView.setRegion(region, animated: true)
    }
    
    private func addPin(coordinate: CLLocationCoordinate2D) {
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.addAnnotation(pin)
    }
    
    
    
    // MARK: Networking Related Functions

    private func fetchPhotos(coordinate: CLLocationCoordinate2D) {
        setDownloadingState(isDownloading: true)
        ApiClient.getPhotosList(latitude: coordinate.latitude, longitude: coordinate.longitude, completion: handleGetPhotosList(photosInfo:error:))
    }
    
    private func handleGetPhotosList(photosInfo: [PhotoInfo], error: Error?) {
        self.noPhotosFoundLabel.isHidden = photosInfo.count > 0
        
        if let error = error {
            self.alertError(title: "Error in fetching photos", message: "\(error.localizedDescription)")
        }
        startLoading(false)
        self.photosInfo = photosInfo
        collectionView.reloadData()
        setDownloadingState(isDownloading: false)
    }
    
    
    // MARK: Alert Message Functions
    
    private func promptDelete(itemAt indexPath: IndexPath) {
        let alertVC = UIAlertController(title: "Confirm", message: "Are you suare you want to delete this photo?", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.performDelete(indexPath: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        [deleteAction, cancelAction].forEach { alertVC.addAction($0) }
        present(alertVC, animated: true)
    }

    private func alertError(title: String, message: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alertVC, animated: true)
    }
    
    
    
    // MARK: CoreData Related Functions
    
    private func setupFetchedResultsController() {
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", pin)
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            
        } catch {
            fatalError("error in fetching photos: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
       if segue.identifier == "showImage" {
           if let indexPaths = collectionView.indexPathsForSelectedItems{
               let destinationController = segue.destination as! PhotoViewerController
               destinationController.photo = DataModel.photosData[indexPaths[0].row]
               collectionView.deselectItem(at: indexPaths[0], animated: false)
           }
       }
   }
    
    
    private func performDelete(indexPath: IndexPath) {
        setupFetchedResultsController()

        DataModel.photosData.remove(at: indexPath.item)
        if shouldDownload {
            photosInfo.remove(at: indexPath.item)
        }
        
        let photoToDelete = fetchedResultsController.object(at: indexPath)
        pin.removeFromPhotos(photoToDelete)
        try? dataController.viewContext.save()
    }

    
    deinit {
        blockOperations.forEach{ $0.cancel() }
        blockOperations.removeAll(keepingCapacity: false)
    }
}




// MARK: UICollectionViewDelegateFlowLayout

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 5) / 3
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 5, left: 2, bottom: 2, right: 0)
    }
    
}



// MARK: UICollectionViewDataSource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        promptDelete(itemAt: indexPath)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        
        if DataModel.photosData.count > indexPath.item {
            let imageData = DataModel.photosData[indexPath.item]
            cell.imageView.image = UIImage(data: imageData)
        } else {
            cell.downloadPhoto(for: photosInfo[indexPath.item], pin: pin)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if shouldDownload {
            return photosInfo.count
        }
        return DataModel.photosData.count
    }
    
    
}



// MARK: MKMapViewDelegate

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let pinId = "pinId"
        return setupAnnotationView(mapView, pinId: pinId, annotation: annotation)
    }
}



// MARK: NSFetchedResultsControllerDelegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    private func deleteOperation(_ indexPath: IndexPath?) -> BlockOperation {
        return BlockOperation(block: { [weak self] in
            if let this = self {
                this.collectionView!.deleteItems(at: [indexPath!])
            }
        })
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            blockOperations.append(deleteOperation(indexPath))
        default: break
        }
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations.removeAll(keepingCapacity: false)
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView!.performBatchUpdates({ () -> Void in
            blockOperations.forEach { $0.start() }
        }, completion: { (finished) -> Void in
            self.blockOperations.removeAll(keepingCapacity: false)
        })
    }
}



