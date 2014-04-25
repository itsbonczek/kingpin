//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "TestHelpers.h"

#import "KPGridClusteringAlgorithm.h"
#import "KPGridClusteringAlgorithmDelegate.h"

#import "KPAnnotation.h"
#import "KPAnnotationTree.h"

#import "KPGeometry.h"

#import "TestAnnotation.h"

@interface KPGridClusteringAlgorithmDelegateClass : NSObject <KPGridClusteringAlgorithmDelegate>
@end

@implementation KPGridClusteringAlgorithmDelegateClass

- (MKMapSize)gridClusteringAlgorithmObtainGridCellSize:(KPGridClusteringAlgorithm *)gridClusteringAlgorithm forMapRect:(MKMapRect)mapRect {
    return MKMapSizeMake(round(mapRect.size.width / 10), round(mapRect.size.height / 10));
}

@end

@interface KPGridClusteringAlgorithmTests : XCTestCase
@end


@implementation KPGridClusteringAlgorithmTests

- (void)testGridClusteringAlgorithmIntegrity
{
    NSMutableArray *annotations = [NSMutableArray array];

    NSUInteger randomNumberOfAnnotations = 1 + arc4random_uniform(10000);

    for (int i = 0; i < randomNumberOfAnnotations; i++) {
        CLLocationDegrees latAdj = ((CLLocationDegrees)(arc4random_uniform(900)) / 10);
        CLLocationDegrees lngAdj = ((CLLocationDegrees)(arc4random_uniform(900)) / 10) * 2;

        TestAnnotation *a = [[TestAnnotation alloc] init];

        a.coordinate = CLLocationCoordinate2DMake(0 + latAdj,
                                                  0 + lngAdj);

        [annotations addObject:a];
    }

    KPAnnotationTree *annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    MKMapRect randomRect = MKMapRectRandom();

    KPGridClusteringAlgorithm *clusteringAlgorithm = [[KPGridClusteringAlgorithm alloc] init];

    __strong KPGridClusteringAlgorithmDelegateClass *clusteringAlgorithmDelegate = [[KPGridClusteringAlgorithmDelegateClass alloc] init];

    MKMapSize cellSize = [clusteringAlgorithmDelegate gridClusteringAlgorithmObtainGridCellSize:clusteringAlgorithm forMapRect:randomRect];

    MKMapRect normalizedMapRect = MKMapRectNormalizeToCellSize(randomRect, cellSize);

    clusteringAlgorithm.delegate = clusteringAlgorithmDelegate;

    NSArray *clusters = [clusteringAlgorithm performClusteringOfAnnotationsInMapRect:randomRect annotationTree:annotationTree];

    NSMutableArray *annotationsCollectedFromClusters = [NSMutableArray array];
    NSArray *annotationsBySearch = [annotationTree annotationsInMapRect:normalizedMapRect];

    [clusters enumerateObjectsUsingBlock:^(KPAnnotation *clusterAnnotation, NSUInteger idx, BOOL *stop) {
        [annotationsCollectedFromClusters addObjectsFromArray:clusterAnnotation.annotations.allObjects];
    }];

    XCTAssertTrue(NSArrayHasDuplicates(annotationsBySearch) == NO);
    XCTAssertTrue(NSArrayHasDuplicates(annotationsCollectedFromClusters) == NO);

    XCTAssertTrue(annotationsBySearch.count == annotationsCollectedFromClusters.count, @"%lu %lu", (unsigned long)annotationsBySearch.count, (unsigned long)annotationsCollectedFromClusters.count);


    NSSet *annotationsBySearchSet = [NSSet setWithArray:annotationsBySearch];
    NSSet *annotationsCollectedFromClustersSet = [NSSet setWithArray:annotationsCollectedFromClusters];

    XCTAssertTrue([annotationsBySearchSet isEqualToSet:annotationsCollectedFromClustersSet]);
}

@end
