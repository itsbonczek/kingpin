//
//  KPGridClusteringAlgorithm.m
//  kingpin
//
//  Created by Stanislaw Pankevich on 12/04/14.
//
//

#import <MapKit/MapKit.h>

#import "KPGridClusteringAlgorithm.h"
#import "KPGridClusteringAlgorithmDelegate.h"

#import "KPAnnotationTree.h"
#import "KPAnnotation.h"

#import "NSArray+KP.h"


/*
 Cell of cluster grid
 --------
 |  2   1 |
 |        |
 |  3   4 |
 --------
 */
typedef enum {
    KPClusterDistributionQuadrantOne   = 1 << 0, // Cluster's point is distributed in North East direction from cell's center i.e. cluster.x > cellCenter.x && cluster.y < cellCenter.y (given MKMapPoints: 0, 0 is on north-west...)
    KPClusterDistributionQuadrantTwo   = 1 << 1,
    KPClusterDistributionQuadrantThree = 1 << 2,
    KPClusterDistributionQuadrantFour  = 1 << 3
} KPClusterDistributionQuadrant;

/*
 cluster 3      cluster 2     cluster 1
 cluster 4  (current cluster) cluster 0
 cluster 5      cluster 6     cluster 7

 2 1  2 1  2 1
 3 4  3 4  3 4

 2 1  curr 2 1
 3 4  cl.  3 4

 2 1  2 1  2 1
 3 4  3 4  3 4
 */
static const int KPClusterConformityTable[8] = {
    KPClusterDistributionQuadrantTwo   | KPClusterDistributionQuadrantThree,  // 0
    KPClusterDistributionQuadrantThree,                                       // 1
    KPClusterDistributionQuadrantThree | KPClusterDistributionQuadrantFour,   // 2
    KPClusterDistributionQuadrantFour,                                        // 3
    KPClusterDistributionQuadrantOne   | KPClusterDistributionQuadrantFour,   // 4
    KPClusterDistributionQuadrantOne,                                         // 5
    KPClusterDistributionQuadrantOne   | KPClusterDistributionQuadrantTwo,    // 6
    KPClusterDistributionQuadrantTwo,                                         // 7
};

/*
 Example: if we have cluster point distributed to first quadrant, then the only adjacent clusters we need to check are 0, 1 and 2, the rest of clusters may be skipped for this current cluster.

  -------- -------- --------
 |        |        |        |
 |  cl.3  |  cl.2  |  cl.1  |
 |        |        |        |
  -------- -------- --------
 |  2   1 |        |        |
 |  cl.4  | current|  cl.0  |  // the middle cell is the every current cluster in -mergeOverlappingClusters
 |  3   4 |        |        |
  -------- -------- --------
 |        |        |        |
 |  cl.5  |  cl.6  |  cl.7  |
 |        |        |        |
  -------- -------- --------
 */
static const int KPClusterAdjacentClustersTable[4][3] = {
    {0, 1, 2},
    {2, 3, 4},
    {4, 5, 6},
    {6, 7, 0},
};

static const int KPAdjacentClustersCoordinateDeltas[8][2] = {
    { 0, 1},  // 0 means that to access coordinate of cell #0 (to the right from current i, j) we must add the following: col + 0, row + 1
    {-1, 1},  // 1
    {-1, 0},  // 2
    {-1, -1}, // 3
    { 0, -1}, // 4
    { 1, -1}, // 5
    { 1, 0},  // 6
    { 1, 1}   // 7
};


typedef struct {
    MKMapRect mapRect;
    NSUInteger annotationIndex;
    BOOL merged;
    KPClusterDistributionQuadrant distributionQuadrant; // One of 0, 1, 2, 4, 8
} kp_cluster_t;


static inline KPClusterDistributionQuadrant KPClusterDistributionQuadrantForPointInsideMapRect(MKMapRect mapRect, MKMapPoint point) {
    MKMapPoint centerPoint = MKMapPointMake(MKMapRectGetMidX(mapRect), MKMapRectGetMidY(mapRect));

    if (point.x >= centerPoint.x) {
        if (point.y >= centerPoint.y) {
            return KPClusterDistributionQuadrantFour;
        } else {
            return KPClusterDistributionQuadrantOne;
        }
    } else {
        if (point.y >= centerPoint.y) {
            return KPClusterDistributionQuadrantThree;
        } else {
            return KPClusterDistributionQuadrantTwo;
        }
    }
}

typedef enum {
    KPClusterMergeResultNone = 0,
    KPClusterMergeResultCurrent = 1,
    KPClusterMergeResultOther = 2,
} kp_cluster_merge_result_t;


@implementation KPGridClusteringAlgorithm

- (NSArray *)performClusteringOfAnnotationsInMapRect:(MKMapRect)mapRect cellSize:(MKMapSize)cellSize annotationTree:(KPAnnotationTree *)annotationTree {
    assert(((uint32_t)mapRect.size.width  % (uint32_t)cellSize.width)  == 0);
    assert(((uint32_t)mapRect.size.height % (uint32_t)cellSize.height) == 0);

    int gridSizeX = mapRect.size.width / cellSize.width;
    int gridSizeY = mapRect.size.height / cellSize.height;

    assert(((uint32_t)mapRect.size.width % (uint32_t)cellSize.width) == 0);

    __block NSMutableArray *newClusters = [[NSMutableArray alloc] initWithCapacity:(gridSizeX * gridSizeY)];

    kp_cluster_t *clusterStorage = malloc((gridSizeX * gridSizeY) * sizeof(kp_cluster_t));

    /*
     We create grid of size (gridSizeX + 2) * (gridSizeY + 2) which looks like

     NULL NULL NULL .... NULL NULL NULL
     NULL    real cluster grid     NULL
     ...         of size           ...
     NULL  (gridSizeX, gridSizeY)  NULL
     NULL NULL NULL .... NULL NULL NULL

     We will use this NULL margin in -mergeOverlappingClusters method to avoid four- or even eight-fold branching when checking boundaries of i and j coordinates
     */
    kp_cluster_t ***clusterGrid = malloc((gridSizeY + 2) * sizeof(kp_cluster_t **));

    for (int col = 0; col < (gridSizeY + 2); col++) {
        clusterGrid[col] = malloc((gridSizeX + 2) * sizeof(kp_cluster_t *));

        // First and last elements are marginal NULL
        clusterGrid[col][0] = NULL;
        clusterGrid[col][gridSizeX + 1] = NULL;
    }

    // memset() is the fastest way to NULLify marginal first and last rows of clusterGrid.
    memset(clusterGrid[0],             0, (gridSizeX + 2) * sizeof(kp_cluster_t *));
    memset(clusterGrid[gridSizeY + 1], 0, (gridSizeX + 2) * sizeof(kp_cluster_t *));

    /* Validation (Debug, remove later) */
    for (int row = 0; row < (gridSizeX + 2); row++) {
        assert(clusterGrid[0][row] == NULL);
        assert(clusterGrid[gridSizeY + 1][row] == NULL);
    }
    for (int col = 0; col < (gridSizeY + 2); col++) {
        assert(clusterGrid[col][0] == NULL);
        assert(clusterGrid[col][gridSizeX + 1] == NULL);
    }

    NSUInteger clusterIndex = 0;

    NSLog(@"Grid: (X, Y) => (%d, %d)", gridSizeX, gridSizeY);

    NSUInteger annotationCounter = 0;
    NSUInteger counter = 0;
    for(int col = 1; col < (gridSizeY + 1); col++) {
        for(int row = 1; row < (gridSizeX + 1); row++){
            counter++;

            int x = mapRect.origin.x + (row - 1) * cellSize.width;
            int y = mapRect.origin.y + (col - 1) * cellSize.height;

            MKMapRect gridRect = MKMapRectMake(x, y, cellSize.width, cellSize.height);

            NSArray *newAnnotations = [annotationTree annotationsInMapRect:gridRect];

            // cluster annotations in this grid piece, if there are annotations to be clustered
            if (newAnnotations.count > 0) {
                KPAnnotation *annotation = [[KPAnnotation alloc] initWithAnnotations:newAnnotations];
                [newClusters addObject:annotation];

                kp_cluster_t *cluster = clusterStorage + clusterIndex;
                cluster->mapRect = gridRect;
                cluster->annotationIndex = clusterIndex;
                cluster->merged = NO;

                cluster->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(gridRect, MKMapPointForCoordinate(annotation.coordinate));

                clusterGrid[col][row] = cluster;

                clusterIndex++;
                annotationCounter += newAnnotations.count;
            } else {
                clusterGrid[col][row] = NULL;
            }
        }
    }

    NSLog(@"AnnotationCounter %lu", (unsigned long)annotationCounter);
    
    /* Validation (Debug, remove later) */
    assert(counter == (gridSizeX * gridSizeY));

    /* Validation (Debug, remove later) */
    for(int col = 0; col < (gridSizeY + 2); col++){
        for(int row = 0; row < (gridSizeX + 2); row++){
            kp_cluster_t *cluster = clusterGrid[col][row];

            if (cluster) {
                assert(cluster->merged == NO);
                assert(cluster->annotationIndex >= 0);
                assert(cluster->annotationIndex < gridSizeX * gridSizeY);
            }
        }
    }

    newClusters = (NSMutableArray *)[self _mergeOverlappingClusters:newClusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];


    for (int col = 0; col < (gridSizeY + 2); col++) {
        free(clusterGrid[col]);
    }
    free(clusterGrid);
    free(clusterStorage);


    return newClusters;
}


- (NSArray *)_mergeOverlappingClusters:(NSArray *)clusters inClusterGrid:(kp_cluster_t ***)clusterGrid gridSizeX:(int)gridSizeX gridSizeY:(int)gridSizeY {
    __block NSMutableArray *mutableClusters = [NSMutableArray arrayWithArray:clusters];
    __block NSMutableIndexSet *indexesOfClustersToBeRemovedAsMerged = [NSMutableIndexSet indexSet];

    kp_cluster_merge_result_t (^checkClustersAndMergeIfNeeded)(kp_cluster_t *cl1, kp_cluster_t *cl2) = ^(kp_cluster_t *cl1, kp_cluster_t *cl2) {
        /* Debug checks (remove later) */
        assert(cl1 && cl1->merged == NO);
        assert(cl2 && cl2->merged == NO);

        assert(cl1->annotationIndex >= 0 && cl1->annotationIndex < gridSizeX * gridSizeY);
        assert(cl2->annotationIndex >= 0 && cl2->annotationIndex < gridSizeX * gridSizeY);


        KPAnnotation *cluster1 = [mutableClusters objectAtIndex:cl1->annotationIndex];
        KPAnnotation *cluster2 = [mutableClusters objectAtIndex:cl2->annotationIndex];

        BOOL clustersIntersect = [self.delegate clusterIntersects:cluster1 anotherCluster:cluster2];

        if (clustersIntersect) {
            NSMutableSet *combinedSet = [NSMutableSet setWithSet:cluster1.annotations];
            [combinedSet unionSet:cluster2.annotations];

            KPAnnotation *newAnnotation = [[KPAnnotation alloc] initWithAnnotationSet:combinedSet];

            MKMapPoint newClusterMapPoint = MKMapPointForCoordinate(newAnnotation.coordinate);

            if (MKMapRectContainsPoint(cl1->mapRect, newClusterMapPoint)) {
                [indexesOfClustersToBeRemovedAsMerged addIndex:cl2->annotationIndex];
                cl2->merged = YES;

                mutableClusters[cl1->annotationIndex] = newAnnotation;

                cl1->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(cl1->mapRect, newClusterMapPoint);

                return KPClusterMergeResultCurrent;
            } else {
                [indexesOfClustersToBeRemovedAsMerged addIndex:cl1->annotationIndex];
                cl1->merged = YES;

                mutableClusters[cl2->annotationIndex] = newAnnotation;

                cl2->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(cl2->mapRect, newClusterMapPoint);

                return KPClusterMergeResultOther;
            }
        }

        return KPClusterMergeResultNone;
    };


    struct {
        int row; // this order "row then col"
        int col; // is important
    } currentClusterCoordinate, adjacentClusterCoordinate;


    kp_cluster_t *currentCellCluster;
    kp_cluster_t *adjacentCellCluster;

    kp_cluster_merge_result_t mergeResult;


    for (int16_t col = 1; col < (gridSizeY + 2); col++) {
        for (int16_t row = 1; row < (gridSizeX + 2); row++) {
        loop_with_explicit_col_and_row:

            assert(col > 0);
            assert(row > 0);

            currentClusterCoordinate.col = col;
            currentClusterCoordinate.row = row;

            currentCellCluster = clusterGrid[col][row];

            if (currentCellCluster == NULL || currentCellCluster->merged) {
                continue;
            }

            int lookupIndexForCurrentCellQuadrant = log2f(currentCellCluster->distributionQuadrant); // we take log2f, because we need to transform KPClusterDistributionQuadrant which is one of the 1, 2, 4, 8 into array index: 0, 1, 2, 3, which we will use for lookups on the next step

            for (int adjacentClustersPositionIndex = 0; adjacentClustersPositionIndex < 3; adjacentClustersPositionIndex++) {
                int adjacentClusterPosition = KPClusterAdjacentClustersTable[lookupIndexForCurrentCellQuadrant][adjacentClustersPositionIndex];

                adjacentClusterCoordinate.col = currentClusterCoordinate.col + KPAdjacentClustersCoordinateDeltas[adjacentClusterPosition][0];
                adjacentClusterCoordinate.row = currentClusterCoordinate.row + KPAdjacentClustersCoordinateDeltas[adjacentClusterPosition][1];

                adjacentCellCluster = clusterGrid[adjacentClusterCoordinate.col][adjacentClusterCoordinate.row];

                // In third condition we use bitwise AND ('&') to check if adjacent cell has distribution of its cluster point which is _complementary_ to a one of the current cell. If it is so, than it worth to make a merge check.
                if (adjacentCellCluster != NULL && adjacentCellCluster->merged == NO && (KPClusterConformityTable[adjacentClusterPosition] & adjacentCellCluster->distributionQuadrant) != 0) {
                    mergeResult = checkClustersAndMergeIfNeeded(currentCellCluster, adjacentCellCluster);

                    // The case when other cluster did adsorb current cluster into itself. This means that we must not continue looking for adjacent clusters because we don't have a current cell now.
                    if (mergeResult == KPClusterMergeResultOther) {
                        // If this other cluster lies upstream (behind current i,j cell), we revert back to its [i,j] coordinate and continue looping
                        if (*(int32_t *)(&currentClusterCoordinate) > *(int32_t *)(&adjacentClusterCoordinate)) {

                            col = adjacentClusterCoordinate.col;
                            row = adjacentClusterCoordinate.row;

                            goto loop_with_explicit_col_and_row;
                        }

                        break; // This breaks from checking adjacent clusters
                    }
                }
            }
        }
    }
    
    // We remove all the indexes of merged clusters that were accumulated by checkClustersAndMergeIfNeeded()
    [mutableClusters removeObjectsAtIndexes:indexesOfClustersToBeRemovedAsMerged];
    
    return mutableClusters;
}



@end
