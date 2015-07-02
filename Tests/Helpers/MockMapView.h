//
//  MockMapView.h
//  kingpin
//
//  Created by Bryan Bonczek on 6/1/14.
//
//

#import <MapKit/MapKit.h>

@interface MockMapView : MKMapView

@property (nonatomic, assign) MKMapRect mockVisibleMapRect;

@end
