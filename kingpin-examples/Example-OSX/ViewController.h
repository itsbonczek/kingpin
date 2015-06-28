//
//  ViewController.h
//  Example-OSX
//
//  Created by Stanislaw Pankevich on 27/06/15.
//
//

#import <Cocoa/Cocoa.h>

@class MKMapView;

@interface ViewController : NSViewController

@property (strong, nonatomic) IBOutlet MKMapView *mapView;

- (IBAction)resetAnnotations:(id)sender;

@end

