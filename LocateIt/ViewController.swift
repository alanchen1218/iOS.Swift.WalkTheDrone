//
//  ViewController.swift
//  LocateIt
//
//  Created by Alan Chen on 5/10/18.
//  Copyright © 2018 Alphie. All rights reserved.
//

import UIKit
import CoreLocation
import ARKit
import MapKit

let kStartingPosition = SCNVector3(0, 0, -0.6)
let kAnimationDurationMoving: TimeInterval = 0.2
let kMovingLengthPerLoop: CGFloat = 0.05
let kRotationRadianPerLoop: CGFloat = 0.2

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate, ARSCNViewDelegate {
    
    var annotation:MKAnnotation!
    var localSearchRequest:MKLocalSearchRequest!
    var localSearch:MKLocalSearch!
    var localSearchResponse:MKLocalSearchResponse!
    var error:NSError!
    var pointAnnotation:MKPointAnnotation!
    var pinAnnotationView:MKPinAnnotationView!
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var arKitView: ARSCNView!
    
    @IBAction func showSearchBar(_ sender: Any) {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    var drone = Drone()
    let locationManager = CLLocationManager()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        mapView.delegate = self
        mapView.showsScale = true
        mapView.showsPointsOfInterest = true
        
        arKitView.delegate = self
        let text = SCNText(string: "Search your destination", extrusionDepth: 1)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        text.materials = [material]
        
        let node = SCNNode()
        node.position = SCNVector3(x: -0.5, y: 0.02, z:-2)
        node.scale = SCNVector3(x: 0.01, y: 0.01, z: 0.01)
        node.geometry = text
        arKitView.scene.rootNode.addChildNode(node)
        arKitView.autoenablesDefaultLighting = true
        
        let sourcecoordinate = locationManager.location?.coordinate
        let destCoordinates = CLLocationCoordinate2DMake(37.3707823, -121.9098350)
        let sourcePlacemark = MKPlacemark(coordinate: sourcecoordinate!)
        let destPlacemark = MKPlacemark(coordinate: destCoordinates)
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destItem = MKMapItem(placemark: destPlacemark)
        
        let directionRequest = MKDirectionsRequest()
        directionRequest.source = sourceItem
        directionRequest.destination = destItem
        directionRequest.transportType = .walking
        let directions = MKDirections(request: directionRequest)
        
        directions.calculate(completionHandler:{
            response, error in
            let route = response?.routes[0]
            self.mapView.add((route?.polyline)!, level: .aboveRoads)
            let rekt = route?.polyline.boundingMapRect
            self.mapView.setRegion(MKCoordinateRegionForMapRect(rekt!), animated: true)
            })
        }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer{
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 3.0
        return renderer
    }
    
    func locationManager(_ _manage: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations[0]
        
        let center = location.coordinate
        let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        let region = MKCoordinateRegion(center: center, span: span)
        
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true
    }
    
    func setupScene() {
        let scene = SCNScene()
        arKitView.scene = scene
    }
    
    func setupConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        arKitView.session.run(configuration)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupConfiguration()
        addDrone()
    }
    
    class Drone: SCNNode {
        func load() {
            guard let virtualObjectScene = SCNScene(named: "Drone.scn") else { return }
            let wrapperNode = SCNNode()
            for child in virtualObjectScene.rootNode.childNodes {
                wrapperNode.addChildNode(child)
            }
            addChildNode(wrapperNode)
        }
    }
    
    func addDrone() {
        drone.load()
        arKitView.scene.rootNode.addChildNode(drone)
    }
    
    @IBAction func upPressed(_ sender: UILongPressGestureRecognizer) {
        let action = SCNAction.moveBy(x: 0, y: kMovingLengthPerLoop, z: 0, duration: kAnimationDurationMoving)
        execute(action: action, sender: sender)
    }
    
    
    @IBAction func downPressed(_ sender: UILongPressGestureRecognizer) {
        let action = SCNAction.moveBy(x: 0, y: -kMovingLengthPerLoop, z: 0, duration: kAnimationDurationMoving)
        execute(action: action, sender: sender)
    }
    @IBAction func leftPressed(_ sender: UILongPressGestureRecognizer) {
        let x = -deltas().cos
        let z = deltas().sin
        moveDrone(x: x, z: z, sender: sender)
    }
    @IBAction func rightPressed(_ sender: UILongPressGestureRecognizer) {
        let x = deltas().cos
        let z = -deltas().sin
        moveDrone(x: x, z: z, sender: sender)
    }
    @IBAction func forwardPressed(_ sender: UILongPressGestureRecognizer) {
        let x = -deltas().sin
        let z = -deltas().cos
        moveDrone(x: x, z: z, sender: sender)
    }
    @IBAction func backPressed(_ sender: UILongPressGestureRecognizer) {
        let x = deltas().sin
        let z = deltas().cos
        moveDrone(x: x, z: z, sender: sender)
    }
    @IBAction func RotateLeftPressed(_ sender: UILongPressGestureRecognizer) {
        rotateDrone(yRadian: kRotationRadianPerLoop, sender: sender)
    }
    @IBAction func RotateRightPressed(_ sender: UILongPressGestureRecognizer) {
        rotateDrone(yRadian: -kRotationRadianPerLoop, sender: sender)
    }
    
    private func rotateDrone(yRadian: CGFloat, sender: UILongPressGestureRecognizer) {
        let action = SCNAction.rotateBy(x: 0, y: yRadian, z: 0, duration: kAnimationDurationMoving)
        execute(action: action, sender: sender)
    }
    
    private func moveDrone(x: CGFloat, z: CGFloat, sender: UILongPressGestureRecognizer) {
        let action = SCNAction.moveBy(x: x, y: 0, z: z, duration: kAnimationDurationMoving)
        execute(action: action, sender: sender)
    }
    
    private func execute(action: SCNAction, sender: UILongPressGestureRecognizer) {
        let loopAction = SCNAction.repeatForever(action)
        if sender.state == .began {
            drone.runAction(loopAction)
        } else if sender.state == .ended {
            drone.removeAllActions()
        }
    }
    
    private func deltas() -> (sin: CGFloat, cos: CGFloat) {
        return (sin: kMovingLengthPerLoop * CGFloat(sin(drone.eulerAngles.y)), cos: kMovingLengthPerLoop * CGFloat(cos(drone.eulerAngles.y)))
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar){
        //1
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        if self.mapView.annotations.count != 0{
            annotation = self.mapView.annotations[0]
            self.mapView.removeAnnotation(annotation)
        }
        //2
        localSearchRequest = MKLocalSearchRequest()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.start { (localSearchResponse, error) -> Void in
            
            if localSearchResponse == nil{
                let alertController = UIAlertController(title: nil, message: "Place Not Found", preferredStyle: UIAlertControllerStyle.alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                return
            }
            //3
            self.pointAnnotation = MKPointAnnotation()
            self.pointAnnotation.title = searchBar.text
            self.pointAnnotation.coordinate = CLLocationCoordinate2D(latitude: localSearchResponse!.boundingRegion.center.latitude, longitude:     localSearchResponse!.boundingRegion.center.longitude)
            
            
            self.pinAnnotationView = MKPinAnnotationView(annotation: self.pointAnnotation, reuseIdentifier: nil)
            self.mapView.centerCoordinate = self.pointAnnotation.coordinate
            self.mapView.addAnnotation(self.pinAnnotationView.annotation!)
        }
    }
    
    
    
    
}

