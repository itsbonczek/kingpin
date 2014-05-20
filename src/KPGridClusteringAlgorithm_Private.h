//
// Copyright 2012 Bryan Bonczek
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "KPGridClusteringAlgorithm.h"


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
static const int KPClusterAdjacentClusterLocationsTable[4][3] = {
    {0, 1, 2},
    {2, 3, 4},
    {4, 5, 6},
    {6, 7, 0},
};


static const uint16_t KPAdjacentClusterPositionDeltas[8][2] = {
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


typedef struct {
    kp_cluster_t ***grid;
    kp_cluster_t *storage;
    uint16_t used; // number of clusters the storage holds
} kp_cluster_grid_t;


static inline void KPClusterGridValidateNULLMargin(kp_cluster_grid_t *clusterGrid, NSUInteger gridSizeX, NSUInteger gridSizeY) {
    for (NSUInteger row = 0; row < (gridSizeX + 2); row++) {
        assert(clusterGrid->grid[0][row] == NULL);
        assert(clusterGrid->grid[gridSizeY + 1][row] == NULL);
    }
    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        assert(clusterGrid->grid[col][0] == NULL);
        assert(clusterGrid->grid[col][gridSizeX + 1] == NULL);
    }
}


/*
 We create grid of size (gridSizeX + 2) * (gridSizeY + 2) which looks like

 NULL NULL NULL .... NULL NULL NULL
 NULL    real cluster grid     NULL
 ...         of size           ...
 NULL  (gridSizeX, gridSizeY)  NULL
 NULL NULL NULL .... NULL NULL NULL

 We will use this NULL margin in -mergeOverlappingClusters method to avoid four- or even eight-fold branching when checking boundaries of i and j coordinates
 */
static inline kp_cluster_grid_t *KPClusterGridCreate(NSUInteger gridSizeX, NSUInteger gridSizeY) {
    kp_cluster_grid_t *clusterGrid = malloc(sizeof(kp_cluster_grid_t));

    clusterGrid->used = 0;
    
    clusterGrid->storage = malloc((gridSizeX * gridSizeY) * sizeof(kp_cluster_t));

    clusterGrid->grid = malloc((gridSizeY + 2) * sizeof(kp_cluster_t **));

    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        clusterGrid->grid[col] = malloc((gridSizeX + 2) * sizeof(kp_cluster_t *));

        // First and last elements are marginal NULL
        clusterGrid->grid[col][0] = NULL;
        clusterGrid->grid[col][gridSizeX + 1] = NULL;
    }

    // memset() is the fastest way to NULLify marginal first and last rows of clusterGrid.
    memset(clusterGrid->grid[0],             0, (gridSizeX + 2) * sizeof(kp_cluster_t *));
    memset(clusterGrid->grid[gridSizeY + 1], 0, (gridSizeX + 2) * sizeof(kp_cluster_t *));

#if DEBUG
    KPClusterGridValidateNULLMargin(clusterGrid, gridSizeX, gridSizeY);
#endif

    return clusterGrid;
}


static inline void KPClusterGridFree(kp_cluster_grid_t *clusterGrid, NSUInteger gridSizeX, NSUInteger gridSizeY) {
    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        free(clusterGrid->grid[col]);
    }
    free(clusterGrid->grid);
    free(clusterGrid->storage);
    free(clusterGrid);
}


static inline kp_cluster_t *KPClusterGridCellCreate(kp_cluster_grid_t *clusterGrid) {
    return clusterGrid->storage + clusterGrid->used++;
}


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


typedef struct {
    uint16_t row; // this order "row then col" is important for comparison method
    uint16_t col; // KPClusterGridCellPositionCompareWithPosition() to work
} kp_cluster_grid_cell_position_t;


static inline NSComparisonResult KPClusterGridCellPositionCompareWithPosition(kp_cluster_grid_cell_position_t *position, kp_cluster_grid_cell_position_t *anotherPosition) {
    if (position->col < anotherPosition->col) {
        return NSOrderedAscending;
    } else if (position->col > anotherPosition->col) {
        return NSOrderedDescending;
    } else {
        if (position->row < anotherPosition->row) {
            return NSOrderedAscending;
        } else if (position->row > anotherPosition->row) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }
}


typedef enum {
    KPClusterMergeResultNone = 0,
    KPClusterMergeResultCurrent = 1,
    KPClusterMergeResultOther = 2,
} kp_cluster_merge_result_t;


typedef kp_cluster_merge_result_t(^kp_cluster_merge_block_t)(kp_cluster_t *, kp_cluster_t *);

@interface KPGridClusteringAlgorithm ()
- (NSArray *)_mergeOverlappingClusters:(NSArray *)clusters inClusterGrid:(kp_cluster_grid_t *)clusterGrid gridSizeX:(NSUInteger)gridSizeX gridSizeY:(NSUInteger)gridSizeY;
@end

