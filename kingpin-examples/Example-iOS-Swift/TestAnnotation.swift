//
//  TestAnnotation.swift
//  kingpin
//
//  Created by Stanislaw Pankevich on 16/03/15.
//
//

import Foundation
import MapKit.MKAnnotation

class TestAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
