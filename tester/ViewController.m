//
//  ViewController.m
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

#import "MyAnnotation.h"
#import "TestAnnotation.h"

#import "KPAnnotation.h"
#import "KPTreeController.h"

static const int kNumberOfTestAnnotations = 20000;

@interface ViewController ()

@property (nonatomic, strong) KPTreeController *treeController;
@property (nonatomic, strong) KPTreeController *treeController2;

@end

@implementation ViewController

- (void)viewDidLoad {

    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    self.treeController = [[KPTreeController alloc] initWithMapView:self.mapView];
    self.treeController.delegate = self;
    self.treeController.animationOptions = UIViewAnimationOptionCurveEaseOut;

    self.treeController2 = [[KPTreeController alloc] initWithMapView:self.mapView];
    self.treeController2.delegate = self;
    self.treeController2.animationOptions = UIViewAnimationOptionCurveEaseOut;

    [self resetAnnotations:nil];
    
    self.mapView.showsUserLocation = YES;
    
    // add two annotations that don't get clustered
    MyAnnotation *nycAnnotation = [MyAnnotation new];
    nycAnnotation.coordinate = [self nycCoord];
    nycAnnotation.title = @"NYC!";
    
    MyAnnotation *sfAnnotation = [MyAnnotation new];
    sfAnnotation.coordinate = [self sfCoord];
    sfAnnotation.title = @"SF!";
    
    [self.mapView addAnnotation:nycAnnotation];
    [self.mapView addAnnotation:sfAnnotation];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.mapView = nil;
}

- (IBAction)resetAnnotations:(id)sender {
    [self.treeController setAnnotations:[self randomAnnotationsForCoordinate:[self sfCoord]]];
    [self.treeController2 setAnnotations:[self randomAnnotationsForCoordinate:[self nycCoord]]];
}


- (NSArray *)randomAnnotationsForCoordinate:(CLLocationCoordinate2D)coordinate {

    NSMutableArray *annotations = [NSMutableArray array];
    
    for (int i = 0; i < kNumberOfTestAnnotations; i++) {
        
        float latAdj = ((random() % 100) / 1000.f);
        float lngAdj = ((random() % 100) / 1000.f);
        
        TestAnnotation *annotation = [[TestAnnotation alloc] init];
        annotation.coordinate = CLLocationCoordinate2DMake(coordinate.latitude + latAdj,
                                                   coordinate.longitude + lngAdj);

        [annotations addObject:annotation];
    }
    
    return annotations;
}

- (CLLocationCoordinate2D)nycCoord {
    return CLLocationCoordinate2DMake(40.77, -73.98);
}

- (CLLocationCoordinate2D)sfCoord {
    return CLLocationCoordinate2DMake(37.85, -122.68);
}


#pragma mark - MKMapView

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.treeController refresh:self.animationSwitch.on];
    [self.treeController2 refresh:self.animationSwitch.on];
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
    MKPinAnnotationView *annotationView = nil;
    
    if ([annotation isKindOfClass:[KPAnnotation class]]) {
        KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
        
        if ([kingpinAnnotation isCluster]) {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorPurple;
        } else {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:[kingpinAnnotation.annotations anyObject] reuseIdentifier:@"pin"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorRed;
        }
        
        annotationView.canShowCallout = YES;
    }

    else if ([annotation isKindOfClass:[MyAnnotation class]]) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"nocluster"];
        annotationView.pinColor = MKPinAnnotationColorGreen;
    }
    
    return annotationView;
}

#pragma mark - KPTreeControllerDelegate

- (void)treeController:(KPTreeController *)tree configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}

@end
