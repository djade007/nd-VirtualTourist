//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import UIKit
import MapKit
import CoreData

class HomeViewController: UIViewController {

    // MARK: Properties
    
    @IBOutlet weak var mapView: MKMapView!

    var longGestureRecognizer: UILongPressGestureRecognizer!
    private var selectedLocation: CLLocation?
    private var selectedPin: Pin!
    private var fetchedResultsController: NSFetchedResultsController<Pin>!

    
    // MARK: LifeCycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.isZoomEnabled = true
        mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.setToolbarHidden(true, animated: false)
        
        setupFetchedResultsController()
        setUpRegion()
        setupPinPointsOnMap()
        setupGestureRecognizer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setToolbarHidden(false, animated: false)
    }
    
    
    // MARK: - Map Region
    private func setUpRegion() {
        if let region = getMapRegion(){
            mapView.setRegion(region, animated: true)
        }
    }
    
    func saveMapRegion(region:MKCoordinateRegion?){
        if let region = region {
            let userRegion = ["latitude":region.center.latitude ,
                              "longitude":region.center.longitude,
                              "latitudeDelta":region.span.latitudeDelta,
                              "longitudeDelta":region.span.longitudeDelta]
            UserDefaults.standard.set(userRegion,forKey:"userRegion")
            
        }
        
    }
    
    func getMapRegion() -> MKCoordinateRegion? {
        if let userRegion  =  UserDefaults.standard.dictionary(forKey: "userRegion"){
            let centerCoordinate = CLLocationCoordinate2D(latitude: userRegion ["latitude"] as! CLLocationDegrees ,longitude: userRegion["longitude"] as! CLLocationDegrees )
            let spanCoordinate = MKCoordinateSpan(latitudeDelta: userRegion ["latitudeDelta"] as! CLLocationDegrees , longitudeDelta: userRegion["longitudeDelta"] as! CLLocationDegrees )
            return MKCoordinateRegion(center: centerCoordinate, span: spanCoordinate)
            
        }
        else {
            return nil
        }
        
    }
    
    
    
    // MARK: Gesture Related Functions
    
    private func setupGestureRecognizer() {
        longGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressed(_:)))
        longGestureRecognizer.minimumPressDuration = 0.3
        
        mapView.addGestureRecognizer(longGestureRecognizer)
    }
    
    @objc private func handleLongPressed(_ gestureRecoginzer: UILongPressGestureRecognizer) {
        if gestureRecoginzer.state == .recognized {
            let location = gestureRecoginzer.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            savePin(coordinate: coordinate)
        }
    }
    
    
    // MARK: Pin Related Functions
   
    private func setupPinPointsOnMap() {
        var annotations = [MKPointAnnotation]()
        fetchedResultsController.fetchedObjects?.forEach {
            let annotation = createAnnotation(pin: $0)
            annotations.append(annotation)
        }
        mapView.addAnnotations(annotations)
    }
    
    private func createCoordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        let lat = CLLocationDegrees(latitude)
        let lon = CLLocationDegrees(longitude)
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return coordinate
    }
    
    private func createAnnotation(pin: Pin) -> MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = createCoordinate(latitude: pin.latitude, longitude: pin.longitude)
        return annotation
    }
    
    
    
    // MARK: Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "visitAlbum",
           let viewController = segue.destination as? PhotoAlbumViewController,
           let selectedLocation = self.selectedLocation {
            viewController.selectedLocation = selectedLocation
            viewController.pin = selectedPin
        }
    }
    
}



// MARK: MKMapViewDelegate

extension HomeViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let coordinate = view.annotation?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        selectedPin = fetchedResultsController.fetchedObjects?.filter {
            $0.latitude == latitude && $0.longitude == longitude
        }.first
        
        self.selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        self.performSegue(withIdentifier: "visitAlbum", sender: nil)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let pinId = "pinId"
        return setupAnnotationView(mapView, pinId: pinId, annotation: annotation)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion(region: mapView.region)
    }
    
}




// MARK: NSFetchedResultsControllerDelegate

extension HomeViewController: NSFetchedResultsControllerDelegate {
    private func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataController.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Error fetching pins: \(error.localizedDescription)")
        }
    }

    private func savePin(coordinate: CLLocationCoordinate2D) {
        let context = DataController.shared.backgroundContext
        let pin = Pin(context: context)
        context.perform {
            pin.latitude = coordinate.latitude
            pin.longitude = coordinate.longitude
            try? context.save()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            let pin = fetchedResultsController.object(at: newIndexPath!)
            addPinToMap(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
        default: break
            
        }
    }
    
    
    private func addPinToMap(coordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
    
}
