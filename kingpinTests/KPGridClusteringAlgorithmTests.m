//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "TestHelpers.h"

#import "KPGridClusteringAlgorithm.h"
#import "KPGridClusteringAlgorithm_Private.h"

#import "KPGridClusteringAlgorithmDelegate.h"

#import "KPAnnotation.h"
#import "KPAnnotationTree.h"

#import "KPGeometry.h"

#import "TestAnnotation.h"

@interface KPGridClusteringAlgorithmDelegateClass : NSObject <KPGridClusteringAlgorithmDelegate>
@end

@implementation KPGridClusteringAlgorithmDelegateClass

- (MKMapSize)gridClusteringAlgorithm:(KPGridClusteringAlgorithm *)gridClusteringAlgorithm obtainGridCellSizeForMapRect:(MKMapRect)mapRect {
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

    MKMapSize cellSize = [clusteringAlgorithmDelegate gridClusteringAlgorithm:clusteringAlgorithm obtainGridCellSizeForMapRect:randomRect];

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

- (void)test_KPClusterGridCellPositionCompareWithPosition {
    NSUInteger gridSizeX = 10, gridSizeY = 10;

    for (int col = 0; col < (gridSizeY + 0); col++) {
        for (int row = 0; row < (gridSizeX + 0); row++) {
            kp_cluster_grid_cell_position_t clusterPosition;
            clusterPosition.row = row;
            clusterPosition.col = col;

            kp_cluster_grid_cell_position_t clusterWhichIsToTheRightPosition;
            clusterWhichIsToTheRightPosition.row = row + 1;
            clusterWhichIsToTheRightPosition.col = col;

            kp_cluster_grid_cell_position_t clusterWhichIsBelowPosition;
            clusterWhichIsBelowPosition.row = row;
            clusterWhichIsBelowPosition.col = col + 1;

            XCTAssertTrue(KPClusterGridCellPositionCompareWithPosition(&clusterPosition, &clusterWhichIsToTheRightPosition) == NSOrderedAscending);
            XCTAssertTrue(KPClusterGridCellPositionCompareWithPosition(&clusterPosition, &clusterWhichIsBelowPosition) == NSOrderedAscending);
        }
    }
}

@end
