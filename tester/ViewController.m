//
//  ViewController.m
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

#import "TestAnnotation.h"

#import "KPAnnotation.h"
#import "KPTreeController.h"

static const int kNumberOfTestAnnotations = 500;

@interface ViewController ()

@property (nonatomic, strong) KPTreeController *treeController;

@end

@implementation ViewController

- (void)viewDidLoad {

    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    self.treeController = [[KPTreeController alloc] initWithMapView:self.mapView];
    self.treeController.delegate = self;
    self.treeController.animationOptions = UIViewAnimationOptionCurveEaseOut;
    [self.treeController setAnnotations:[self annotations]];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.mapView = nil;
}


- (NSArray *)annotations {
    
    // build an NYC and SF cluster
    
    NSMutableArray *annotations = [NSMutableArray array];
    
    CLLocationCoordinate2D nycCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D sfCoord = CLLocationCoordinate2DMake(37.85, -122.68);
    
    for (int i=0; i< kNumberOfTestAnnotations / 2; i++) {
        
        float latAdj = ((random() % 100) / 1000.f);
        float lngAdj = ((random() % 100) / 1000.f);
        
        TestAnnotation *a1 = [[TestAnnotation alloc] init];
        a1.coordinate = CLLocationCoordinate2DMake(nycCoord.latitude + latAdj, 
                                                   nycCoord.longitude + lngAdj);
        [annotations addObject:a1];
        
        TestAnnotation *a2 = [[TestAnnotation alloc] init];
        a2.coordinate = CLLocationCoordinate2DMake(sfCoord.latitude + latAdj,
                                                   sfCoord.longitude + lngAdj);
        [annotations addObject:a2];

    }
    
    return annotations;
}

- (CLLocationCoordinate2D)testMapStartCoordinate {
    return CLLocationCoordinate2DMake(45, -75);
}

- (CLLocationCoordinate2D)testMapEndCoordinate {
    return CLLocationCoordinate2DMake(40, -70);
}

// the map rect that contains all of the coordinates

- (MKMapRect)testMapRect {
    
    MKMapPoint start = MKMapPointForCoordinate([self testMapStartCoordinate]);
    MKMapPoint end = MKMapPointForCoordinate([self testMapEndCoordinate]);
    
    MKMapRect exactRegion = MKMapRectMake(start.x,
                                          start.y,
                                          end.x - start.x,
                                          end.y - start.y);
    
    return exactRegion;
}



#pragma mark - MKMapView

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.treeController refresh:self.animationSwitch.on];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    
    if([view.annotation isKindOfClass:[KPAnnotation class]]){
        
        KPAnnotation *cluster = (KPAnnotation *)view.annotation;
        
        if(cluster.annotations.count > 1){
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(cluster.coordinate,
                                                                       cluster.radius * 2.5f,
                                                                       cluster.radius * 2.5f)
                           animated:YES];
        }
    }
    
    
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    KPAnnotation *a = (KPAnnotation *)annotation;
    
    MKPinAnnotationView *v = nil;
    
    if(a.annotations.count > 1){
        v = [[MKPinAnnotationView alloc] initWithAnnotation:a reuseIdentifier:@"cluster"];
        v.pinColor = MKPinAnnotationColorPurple;
    }
    else {
        v = [[MKPinAnnotationView alloc] initWithAnnotation:a reuseIdentifier:@"pin"];
        v.pinColor = MKPinAnnotationColorRed;
    }
    
    v.canShowCallout = YES;
    
    return v;
    
}

#pragma mark - KPTreeControllerDelegate

- (NSString *)treeController:(KPTreeController *)tree titleForCluster:(KPAnnotation *)cluster {
    return [NSString stringWithFormat:@"%i custom annotations", cluster.annotations.count];
}

@end
