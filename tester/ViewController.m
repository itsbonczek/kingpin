//
//  ViewController.m
//  MapTest
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

#import "KPTreeController.h"
#import "KPTreeControllerRework.h"

#import "MyAnnotation.h"
#import "TestAnnotation.h"

#import "KPAnnotation.h"

#import "TestHelpers.h"

static const int kNumberOfTestAnnotations = 20000;

@interface ViewController () <KPTreeControllerDelegate, KPTreeControllerReworkDelegate>

@property (nonatomic, strong) KPTreeController *treeController;
@property (nonatomic, strong) KPTreeControllerRework *treeController2;

@end

@implementation ViewController

- (void)viewDidLoad {

    [super viewDidLoad];
    
    self.mapView.delegate = self;

    /*
     Disable old tree controller for now
    self.treeController = [[KPTreeController alloc] initWithMapView:self.mapView];
    self.treeController.delegate = self;
    self.treeController.animationOptions = UIViewAnimationOptionCurveEaseOut;
    [self.treeController setAnnotations:[self annotations]];
     */

    self.treeController2 = [[KPTreeControllerRework alloc] initWithMapView:self.mapView];
    self.treeController2.delegate = self;

    KPTreeControllerReworkConfiguration configuration = self.treeController2.configuration;
    configuration.animationOptions = UIViewAnimationOptionCurveEaseOut;
    self.treeController2.configuration = configuration;

    [self.treeController2 setAnnotations:[self annotations]];
    
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
    //[self.treeController setAnnotations:[self annotations]];
    [self.treeController2 setAnnotations:[self annotations]];
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


#pragma mark - MKMapView

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    //[self.treeController refresh:self.animationSwitch.on];
    Benchmark(1, ^{
        [self.treeController2 refresh:self.animationSwitch.on];
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

#pragma mark - <KPTreeControllerDelegate>

- (void)treeController:(KPTreeController *)tree configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}

- (BOOL)treeControllerShouldClusterAnnotations:(KPTreeControllerRework *)tree {
    return YES;
}

@end
