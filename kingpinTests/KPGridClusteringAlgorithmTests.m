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

- (id)gridClusteringAlgorithm:(KPGridClusteringAlgorithm *)gridClusteringAlgorithm clusterAnnotationForAnnotations:(NSArray *)annotations inClusterGridRect:(MKMapRect)gridRect {
    return [[KPAnnotation alloc] initWithAnnotations:annotations];
}

- (BOOL)gridClusteringAlgorithm:(KPGridClusteringAlgorithm *)gridClusteringAlgorithm clusterIntersects:(KPAnnotation *)clusterAnnotation anotherCluster:(KPAnnotation *)anotherClusterAnnotation {
    return YES;
}

@end

@interface KPGridClusteringAlgorithmTests : XCTestCase
@end


@implementation KPGridClusteringAlgorithmTests

- (void)test_gridClusteringAlgorithmIntegrity
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

            XCTAssertTrue(KPClusterGridCellPositionCompareWithPosition(&clusterPosition, &clusterPosition) == NSOrderedSame);
            
            XCTAssertTrue(KPClusterGridCellPositionCompareWithPosition(&clusterPosition, &clusterWhichIsToTheRightPosition) == NSOrderedAscending);
            XCTAssertTrue(KPClusterGridCellPositionCompareWithPosition(&clusterPosition, &clusterWhichIsBelowPosition) == NSOrderedAscending);

            uint32_t clusterPositionAbsoluteOffset = *((uint32_t *)&clusterPosition);
            uint32_t clusterWhichIsToTheRightPositionAbsoluteOffset = *((uint32_t *)&clusterWhichIsToTheRightPosition);
            uint32_t clusterWhichIsBelowPositionAbsoluteOffset = *((uint32_t *)&clusterWhichIsBelowPosition);

            XCTAssertTrue((clusterWhichIsToTheRightPositionAbsoluteOffset - clusterPositionAbsoluteOffset) == 1);
            XCTAssertTrue((clusterWhichIsBelowPositionAbsoluteOffset - clusterPositionAbsoluteOffset) == 65536);
        }
    }
}

- (void)test_mergeOverlappingClusters {
    KPGridClusteringAlgorithm *clusteringAlgorithm = [[KPGridClusteringAlgorithm alloc] init];
    __strong KPGridClusteringAlgorithmDelegateClass *clusteringAlgorithmDelegate = [KPGridClusteringAlgorithmDelegateClass new];

    clusteringAlgorithm.delegate = clusteringAlgorithmDelegate;

    {
        NSUInteger gridSizeX = 2;
        NSUInteger gridSizeY = 2;

        TestAnnotation *annotation11 = [[TestAnnotation alloc] init];
        annotation11.coordinate = CLLocationCoordinate2DMake(1, 0);

        TestAnnotation *annotation12 = [[TestAnnotation alloc] init];
        annotation12.coordinate = CLLocationCoordinate2DMake(1, 1);

        TestAnnotation *annotation21 = [[TestAnnotation alloc] init];
        annotation21.coordinate = CLLocationCoordinate2DMake(0, 0);

        TestAnnotation *annotation22 = [[TestAnnotation alloc] init];
        annotation22.coordinate = CLLocationCoordinate2DMake(0, 1);

        MKMapPoint annotationMapPoint11 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(1, 0));
        MKMapPoint annotationMapPoint12 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(1, 1));
        MKMapPoint annotationMapPoint21 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(0, 0));
        MKMapPoint annotationMapPoint22 = MKMapPointForCoordinate(CLLocationCoordinate2DMake(0, 1));

        MKMapSize cellSize = (MKMapSize){
            annotationMapPoint12.x - annotationMapPoint11.x,
            annotationMapPoint12.y - annotationMapPoint11.y,
        };

        MKMapRect mapRect11 = (MKMapRect) {
            annotationMapPoint11.x - cellSize.width / 2,
            annotationMapPoint11.y - cellSize.height / 2,
        };

        MKMapRect mapRect12 = (MKMapRect) {
            annotationMapPoint12.x - cellSize.width / 2,
            annotationMapPoint12.y - cellSize.height / 2,
        };

        MKMapRect mapRect21 = (MKMapRect) {
            annotationMapPoint21.x - cellSize.width / 2,
            annotationMapPoint21.y - cellSize.height / 2,
        };

        MKMapRect mapRect22 = (MKMapRect) {
            annotationMapPoint22.x - cellSize.width / 2,
            annotationMapPoint22.y - cellSize.height / 2,
        };

        KPAnnotation *clusterAnnotation11 = [[KPAnnotation alloc] initWithAnnotations:@[ annotation11 ]];
        KPAnnotation *clusterAnnotation12 = [[KPAnnotation alloc] initWithAnnotations:@[ annotation12 ]];
        KPAnnotation *clusterAnnotation21 = [[KPAnnotation alloc] initWithAnnotations:@[ annotation21 ]];
        KPAnnotation *clusterAnnotation22 = [[KPAnnotation alloc] initWithAnnotations:@[ annotation22 ]];


#pragma mark Two complementary annotations on positions {1, 1} and {1, 2}

        {
            kp_cluster_t **clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);

            kp_cluster_t *clusterCell11 = malloc(sizeof(kp_cluster_t));
            kp_cluster_t *clusterCell12 = malloc(sizeof(kp_cluster_t));

            clusterCell11->annotationIndex = 0;
            clusterCell11->distributionQuadrant = KPClusterDistributionQuadrantOne;
            clusterCell11->state = KPClusterStateHasData;
            clusterCell11->mapRect = mapRect11;

            clusterCell12->annotationIndex = 1;
            clusterCell12->distributionQuadrant = KPClusterDistributionQuadrantTwo;
            clusterCell12->state = KPClusterStateHasData;
            clusterCell12->mapRect = mapRect12;

            clusterGrid[1][1] = *clusterCell11;
            clusterGrid[1][2] = *clusterCell12;

            clusterGrid[2][1].state = KPClusterStateEmpty;
            clusterGrid[2][2].state = KPClusterStateEmpty;

            NSArray *clusters = @[ clusterAnnotation11, clusterAnnotation12 ];

            clusters = [clusteringAlgorithm _mergeOverlappingClusters:clusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];

            XCTAssertTrue(clusters.count == 1);

            KPAnnotation *firstCluster = clusters.firstObject;

            XCTAssertTrue(CLLocationCoordinates2DEqual(firstCluster.coordinate, CLLocationCoordinate2DMake(1, 0.5)));
            
            KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);
        }


#pragma mark Two non-complementary annotations on positions {1, 1} and {1, 2}

        {
            kp_cluster_t **clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);

            kp_cluster_t clusterCell11;
            kp_cluster_t clusterCell12;

            clusterCell11.annotationIndex = 0;
            clusterCell11.distributionQuadrant = KPClusterDistributionQuadrantTwo;
            clusterCell11.state = KPClusterStateHasData;
            clusterCell11.mapRect = mapRect11;

            clusterCell12.annotationIndex = 1;
            clusterCell12.distributionQuadrant = KPClusterDistributionQuadrantOne;
            clusterCell12.state = KPClusterStateHasData;
            clusterCell12.mapRect = mapRect12;

            clusterGrid[1][1] = clusterCell11;
            clusterGrid[1][2] = clusterCell12;

            clusterGrid[2][1].state = KPClusterStateEmpty;
            clusterGrid[2][2].state = KPClusterStateEmpty;

            NSArray *clusters = @[ clusterAnnotation11, clusterAnnotation12 ];

            clusters = [clusteringAlgorithm _mergeOverlappingClusters:clusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];

            XCTAssertTrue(clusters.count == 2);

            KPAnnotation *firstCluster = clusters.firstObject;
            KPAnnotation *lastCluster = clusters.lastObject;

            XCTAssertTrue(CLLocationCoordinates2DEqual(firstCluster.coordinate, CLLocationCoordinate2DMake(1, 0)));
            XCTAssertTrue(CLLocationCoordinates2DEqual(lastCluster.coordinate, CLLocationCoordinate2DMake(1, 1)));

            KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);
        }


#pragma mark Four complementary annotations on positions {1, 1}, {1, 2}, {2, 1}, {2, 2}


        {
            kp_cluster_t **clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);

            kp_cluster_t *clusterCell11 = malloc(sizeof(kp_cluster_t));
            kp_cluster_t *clusterCell12 = malloc(sizeof(kp_cluster_t));
            kp_cluster_t *clusterCell21 = malloc(sizeof(kp_cluster_t));
            kp_cluster_t *clusterCell22 = malloc(sizeof(kp_cluster_t));

            clusterCell11->annotationIndex = 0;
            clusterCell11->distributionQuadrant = KPClusterDistributionQuadrantFour;
            clusterCell11->state = KPClusterStateHasData;
            clusterCell11->mapRect = mapRect11;

            clusterCell12->annotationIndex = 1;
            clusterCell12->distributionQuadrant = KPClusterDistributionQuadrantThree;
            clusterCell12->state = KPClusterStateHasData;
            clusterCell12->mapRect = mapRect12;

            clusterCell21->annotationIndex = 2;
            clusterCell21->distributionQuadrant = KPClusterDistributionQuadrantOne;
            clusterCell21->state = KPClusterStateHasData;
            clusterCell21->mapRect = mapRect21;

            clusterCell22->annotationIndex = 3;
            clusterCell22->distributionQuadrant = KPClusterDistributionQuadrantTwo;
            clusterCell22->state = KPClusterStateHasData;
            clusterCell22->mapRect = mapRect22;

            clusterGrid[1][1] = *clusterCell11;
            clusterGrid[1][2] = *clusterCell12;
            clusterGrid[2][1] = *clusterCell21;
            clusterGrid[2][2] = *clusterCell22;

            NSArray *clusters = @[ clusterAnnotation11, clusterAnnotation12, clusterAnnotation21, clusterAnnotation22 ];

            clusters = [clusteringAlgorithm _mergeOverlappingClusters:clusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];

            XCTAssertTrue(clusters.count == 1);

            KPAnnotation *firstCluster = clusters.firstObject;

            XCTAssertTrue(CLLocationCoordinates2DEqual(firstCluster.coordinate, CLLocationCoordinate2DMake(0.5, 0.5)));
            
            KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);
        }


#pragma mark Four non-complementary annotations on positions {1, 1}, {1, 2}, {2, 1}, {2, 2}


        {
            kp_cluster_t **clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);

            kp_cluster_t clusterCell11;
            kp_cluster_t clusterCell12;
            kp_cluster_t clusterCell21;
            kp_cluster_t clusterCell22;

            clusterCell11.annotationIndex = 0;
            clusterCell11.distributionQuadrant = KPClusterDistributionQuadrantTwo;
            clusterCell11.state = KPClusterStateHasData;
            clusterCell11.mapRect = mapRect11;

            clusterCell12.annotationIndex = 1;
            clusterCell12.distributionQuadrant = KPClusterDistributionQuadrantOne;
            clusterCell12.state = KPClusterStateHasData;
            clusterCell12.mapRect = mapRect12;

            clusterCell21.annotationIndex = 2;
            clusterCell21.distributionQuadrant = KPClusterDistributionQuadrantThree;
            clusterCell21.state = KPClusterStateHasData;
            clusterCell21.mapRect = mapRect21;

            clusterCell22.annotationIndex = 3;
            clusterCell22.distributionQuadrant = KPClusterDistributionQuadrantFour;
            clusterCell22.state = KPClusterStateHasData;
            clusterCell22.mapRect = mapRect22;

            clusterGrid[1][1] = clusterCell11;
            clusterGrid[1][2] = clusterCell12;
            clusterGrid[2][1] = clusterCell21;
            clusterGrid[2][2] = clusterCell22;

            NSArray *clusters = @[ clusterAnnotation11, clusterAnnotation12, clusterAnnotation21, clusterAnnotation22 ];

            NSArray *clustersAfterMerge = [clusteringAlgorithm _mergeOverlappingClusters:clusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];

            XCTAssertTrue(clusters.count == 4);

            XCTAssertTrue([clustersAfterMerge isEqual:clusters]);
            KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);
        }


    }

}

@end
