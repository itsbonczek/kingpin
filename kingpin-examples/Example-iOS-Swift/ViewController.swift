//
//  ViewController.swift
//  kingpinSwiftTestApplication
//
//  Created by Stanislaw Pankevich on 16/03/15.
//
//

import UIKit
import MapKit
import kingpin

let NumberOfAnnotations: Int = 1000;

class ViewController: UIViewController {

    private var clusteringController : KPClusteringController!

    // MARK: UIViewController
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let algorithm : KPGridClusteringAlgorithm = KPGridClusteringAlgorithm()

        algorithm.annotationSize = CGSizeMake(25, 50)
        algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategy.TwoPhase;

        clusteringController = KPClusteringController(mapView: self.mapView, clusteringAlgorithm: algorithm)
        clusteringController.delegate = self

        clusteringController.setAnnotations(annotations())

        mapView.centerCoordinate = self.nycCoord()
    }

    // MARK: Fake annotation set

    func annotations() -> [TestAnnotation] {
        var annotations: [TestAnnotation] = []

        let nycCoord: CLLocationCoordinate2D = self.nycCoord()
        let sfCoord:  CLLocationCoordinate2D = self.sfCoord()

        for var i = 0; i < NumberOfAnnotations / 2; i++ {
            let latAdj: Double = ((Double(random()) % 1000) / 1000.0)
            let lngAdj: Double = ((Double(random()) % 1000) / 1000.0)

            let coordinate1 : CLLocationCoordinate2D = CLLocationCoordinate2DMake(nycCoord.latitude + latAdj, nycCoord.longitude + lngAdj)
            let coordinate2 : CLLocationCoordinate2D = CLLocationCoordinate2DMake(sfCoord.latitude + latAdj, sfCoord.longitude + lngAdj)

            let a1: TestAnnotation = TestAnnotation(coordinate: coordinate1)
            let a2: TestAnnotation = TestAnnotation(coordinate: coordinate2)

            annotations.append(a1)
            annotations.append(a2)
        }

        return annotations
    }

    func nycCoord() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(40.77, -73.98)
    }

    func sfCoord() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(37.85, -122.68)
    }
}

// MARK: <MKMapViewDelegate>

extension ViewController : MKMapViewDelegate {
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if annotation is MKUserLocation {
            // return nil so map view draws "blue dot" for standard user location
            return nil
        }

        var annotationView : MKPinAnnotationView?

        if annotation is KPAnnotation {
            let a = annotation as! KPAnnotation

            if a.isCluster() {
                annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("cluster") as? MKPinAnnotationView

                if (annotationView == nil) {
                    annotationView = MKPinAnnotationView(annotation: a, reuseIdentifier: "cluster")
                }

                annotationView!.pinColor = .Purple
            }

            else {
                annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("pin") as? MKPinAnnotationView

                if (annotationView == nil) {
                    annotationView = MKPinAnnotationView(annotation: a, reuseIdentifier: "pin")
                }

                annotationView!.pinColor = .Red
            }

            annotationView!.canShowCallout = true;
        }

        return annotationView;
    }

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        clusteringController.refresh(true)
    }

    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if view.annotation is KPAnnotation {
            let cluster = view.annotation as! KPAnnotation

            if cluster.annotations.count > 1 {
                let region = MKCoordinateRegionMakeWithDistance(cluster.coordinate,
                    cluster.radius * 2.5,
                    cluster.radius * 2.5)

                mapView.setRegion(region, animated: true)
            }
        }
    }
}

// MARK: <CLControllerDelegate>

extension ViewController : KPClusteringControllerDelegate {
    func clusteringControllerShouldClusterAnnotations(clusteringController: KPClusteringController!) -> Bool {
        return true
    }
}
