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
#import "TestHelpers.h"

#import "KPGridClusteringAlgorithm_Private.h"

#import "Datasets.h"

static const int kNumberOfTestAnnotations = 20000;

@interface ViewController () <KPClusteringControllerDelegate, KPClusteringControllerDelegate>

@property (strong, nonatomic) KPClusteringController *clusteringController;
@property (strong, nonatomic) KPClusteringController *clusteringController2;

@end

@implementation ViewController

- (void)viewDidLoad {

    [super viewDidLoad];

    self.mapView.delegate = self;

    /*
     Disable old tree controller for now
    self.clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView];
    self.clusteringController.delegate = self;
    self.clusteringController.animationOptions = UIViewAnimationOptionCurveEaseOut;
    [self.clusteringController setAnnotations:[self annotations]];
     */
    
    KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];
    algorithm.annotationSize = CGSizeMake(25, 50);
    algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;

    self.clusteringController2 = [[KPClusteringController alloc] initWithMapView:self.mapView
                                                 clusteringAlgorithm:algorithm];
    self.clusteringController2.delegate = self;

    self.clusteringController2.animationOptions = UIViewAnimationOptionCurveEaseOut;

    [self.clusteringController2 setAnnotations:[self annotations]];
    
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
    //[self.clusteringController setAnnotations:[self annotations]];
    [self.clusteringController2 setAnnotations:[self annotations]];
}


- (NSArray *)annotations {

    // return dataset1_8000_Moscow();
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


#pragma mark - MKMapView

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    //[self.clusteringController refresh:self.animationSwitch.on];
    Benchmark(1, ^{
        [self.clusteringController2 refresh:self.animationSwitch.on];
    });
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
    
    MKPinAnnotationView *v = nil;
    
    if([annotation isKindOfClass:[KPAnnotation class]]){
    
        KPAnnotation *a = (KPAnnotation *)annotation;
        
        if([annotation isKindOfClass:[MKUserLocation class]]){
            return nil;
        }
        
        if([a isCluster]){
           
            v = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if(!v){
                v = [[MKPinAnnotationView alloc] initWithAnnotation:a reuseIdentifier:@"cluster"];
            }
            
            v.pinColor = MKPinAnnotationColorPurple;
        }
        else {
            
            v = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
            
            if(!v){
                v = [[MKPinAnnotationView alloc] initWithAnnotation:[a.annotations anyObject]
                                                    reuseIdentifier:@"pin"];
            }
            
            v.pinColor = MKPinAnnotationColorRed;
        }
        
        v.canShowCallout = YES;
    }
    else if([annotation isKindOfClass:[MyAnnotation class]]) {
        v = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"nocluster"];
        v.pinColor = MKPinAnnotationColorGreen;
    }
    
    return v;
    
}

#pragma mark - <KPClusteringControllerDelegate>

- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}

- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController {
    return YES;
}

@end
