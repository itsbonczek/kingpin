//
//  KPClusteringControllerTests.m
//  kingpin-dev
//
//  Created by Stanislaw Pankevich on 01/10/15.
//
//

#import <XCTest/XCTest.h>

#import "KPClusteringController.h"
#import "KPGridClusteringAlgorithm.h"

@interface FakeDelegate : NSObject <KPClusteringControllerDelegate>
@property (readonly, nonatomic) BOOL callReceived;
@end

@implementation FakeDelegate

- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController {
    _callReceived = YES;
}

@end

@interface KPClusteringControllerTests : XCTestCase
@end

@implementation KPClusteringControllerTests

- (void)test_setAnnotationsDoesCall_delegate_willUpdateVisibleAnnotations_WhenMapViewHasNonZeroVisibleRect {
    FakeDelegate *fakeDelegate = [FakeDelegate new];

    KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];

    MKMapView *mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];

    KPClusteringController *clusteringController = [[KPClusteringController alloc] initWithMapView:mapView clusteringAlgorithm:algorithm];

    clusteringController.delegate = fakeDelegate;

    [clusteringController setAnnotations:@[]];

    XCTAssertTrue(fakeDelegate.callReceived, @"");
}

// FIXME: write better test for this sort of crash
// The following ensures that we do not proceed with clustering algorithm if map's visible rect is zero
- (void)test_setAnnotationsDoesNotCall_delegate_willUpdateVisibleAnnotations_WhenMapViewHasNonZeroVisibleRect {
    FakeDelegate *fakeDelegate = [FakeDelegate new];

    KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];

    MKMapView *mapView = [[MKMapView alloc] initWithFrame:CGRectZero];

    KPClusteringController *clusteringController = [[KPClusteringController alloc] initWithMapView:mapView clusteringAlgorithm:algorithm];

    clusteringController.delegate = fakeDelegate;

    [clusteringController setAnnotations:@[]];
    
    XCTAssertFalse(fakeDelegate.callReceived, @"");
}

@end
