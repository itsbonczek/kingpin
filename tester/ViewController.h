//
//  ViewController.h
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <MapKit/MapKit.h>

@interface ViewController : UIViewController <MKMapViewDelegate>
 
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) IBOutlet UISwitch *animationSwitch;

- (IBAction)resetAnnotations:(id)sender;

@end
