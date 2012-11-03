//
//  ViewController.h
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <MKMapViewDelegate>
 
@property (nonatomic, strong) IBOutlet MKMapView *mapView;
@property (nonatomic) IBOutlet UISwitch *animationSwitch;

@end
