//
//  ViewController.m
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

#import "KPAnnotation.h"
#import "KPGridClusteringAlgorithm.h"
#import "KPClusteringController.h"
#import "MyAnnotation.h"
#import "TestAnnotation.h"

#import "KPGridClusteringAlgorithm_Private.h"

static const int kNumberOfTestAnnotations = 100000;

@interface ViewController () <KPClusteringControllerDelegate, KPClusteringControllerDelegate>

@property (strong, nonatomic) KPClusteringController *clusteringController;

@end

@implementation ViewController

- (void)viewDidLoad {

    [super viewDidLoad];

    self.mapView.delegate = self;
    
    KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];
    algorithm.annotationSize = CGSizeMake(25, 50);
    algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;

    self.clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView
                                                 clusteringAlgorithm:algorithm];
    self.clusteringController.delegate = self;

    self.clusteringController.animationOptions = UIViewAnimationOptionCurveEaseOut;

    [self.clusteringController setAnnotations:[self annotations]];
    
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
    [self.clusteringController setAnnotations:[self annotations]];
}


- (NSArray *)annotations {
    // build an NYC and SF cluster
    
    NSMutableArray *annotations = [NSMutableArray array];
    
    CLLocationCoordinate2D nycCoord = [self nycCoord];
    CLLocationCoordinate2D sfCoord = [self sfCoord];
    
    for (int i=0; i< kNumberOfTestAnnotations / 2; i++) {
        
        float latAdj = ((random() % 1000) / 1000.f);
        float lngAdj = ((random() % 1000) / 1000.f);
        
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

- (CLLocationCoordinate2D)nycCoord {
    return CLLocationCoordinate2DMake(40.77, -73.98);
}

- (CLLocationCoordinate2D)sfCoord {
    return CLLocationCoordinate2DMake(37.85, -122.68);
}


#pragma mark - <MKMapViewDelegate>

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.clusteringController refresh:self.animationSwitch.on];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if ([view.annotation isKindOfClass:[KPAnnotation class]]) {
        
        KPAnnotation *cluster = (KPAnnotation *)view.annotation;
        
        if (cluster.annotations.count > 1){
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
        KPAnnotation *a = (KPAnnotation *)annotation;

        if ([annotation isKindOfClass:[MKUserLocation class]]){
            return nil;
        }

        if (a.isCluster) {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:a reuseIdentifier:@"cluster"];
            }

            annotationView.pinColor = MKPinAnnotationColorPurple;
        }

        else {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];

            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:[a.annotations anyObject]
                                                    reuseIdentifier:@"pin"];
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

#pragma mark - <KPClusteringControllerDelegate>

- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}

- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController {
    return YES;
}

- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController {
    NSLog(@"Clustering controller %@ will update visible annotations", clusteringController);
}

- (void)clusteringControllerDidUpdateVisibleMapAnnotations:(KPClusteringController *)clusteringController {
    NSLog(@"Clustering controller %@ did update visible annotations", clusteringController);
}

- (void)clusteringController:(KPClusteringController *)clusteringController performAnimations:(void (^)())animations withCompletionHandler:(void (^)(BOOL))completion {
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.6 options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
}

@end
