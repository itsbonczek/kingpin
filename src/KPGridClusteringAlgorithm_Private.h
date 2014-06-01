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

typedef enum {
    KPClusterStateEmpty   =  0,
    KPClusterStateHasData =  1,
    KPClusterStateMerged  = -1,
} kp_cluster_state_t;

typedef struct {
    MKMapRect mapRect; // 32
    NSUInteger annotationIndex:32; // 4
    kp_cluster_state_t state:2;
    KPClusterDistributionQuadrant distributionQuadrant:30; // One of 0, 1, 2, 4, 8
} kp_cluster_t;

static inline void KPClusterGridValidateNULLMargin(kp_cluster_t **clusterGrid, NSUInteger gridSizeX, NSUInteger gridSizeY) {
    for (NSUInteger row = 0; row < (gridSizeX + 2); row++) {
        assert(clusterGrid[0][row].state == KPClusterStateEmpty);
        assert(clusterGrid[gridSizeY + 1][row].state == KPClusterStateEmpty);
    }
    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        assert(clusterGrid[col][0].state == KPClusterStateEmpty);
        assert(clusterGrid[col][gridSizeX + 1].state == KPClusterStateEmpty);
    }
}

static inline kp_cluster_t **KPClusterGridCreate(NSUInteger gridSizeX, NSUInteger gridSizeY) {
    kp_cluster_t **clusterGrid = malloc((gridSizeY + 2) * sizeof(kp_cluster_t *));

    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        clusterGrid[col] = malloc((gridSizeX + 2) * sizeof(kp_cluster_t));

        clusterGrid[col][0].state             = KPClusterStateEmpty;
        clusterGrid[col][gridSizeX + 1].state = KPClusterStateEmpty;
    }

    memset(clusterGrid[0], 0, (gridSizeX + 2) * sizeof(kp_cluster_t));
    memset(clusterGrid[gridSizeY + 1], 0, (gridSizeX + 2) * sizeof(kp_cluster_t));

    return clusterGrid;
}

static inline void KPClusterGridFree(kp_cluster_t **clusterGrid, NSUInteger gridSizeX, NSUInteger gridSizeY) {
    for (NSUInteger col = 0; col < (gridSizeY + 2); col++) {
        free(clusterGrid[col]);
    }
    free(clusterGrid);
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

@interface KPGridClusteringAlgorithm (Private)

- (NSArray *)_mergeOverlappingClusters:(NSArray *)clusters
                             inMapView:(MKMapView *)mapView
                           clusterGrid:(kp_cluster_t **)clusterGrid
                             gridSizeX:(NSUInteger)gridSizeX
                             gridSizeY:(NSUInteger)gridSizeY;

@end
