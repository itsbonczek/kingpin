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

#import <MapKit/MapKit.h>

#import "KPGridClusteringAlgorithm.h"
#import "KPGridClusteringAlgorithm_Private.h"

#import "KPGridClusteringAlgorithmDelegate.h"

#import "KPAnnotationTree.h"
#import "KPAnnotation.h"

#import "KPGeometry.h"

#import "NSArray+KP.h"


@implementation KPGridClusteringAlgorithmConfiguration

- (id)init {
    self = [super init];

    if (self == nil) return nil;

    self.gridSize = (CGSize){60.f, 60.f};

    return self;
}

@end

@interface KPGridClusteringAlgorithm ()
@property (strong, readwrite, nonatomic) KPGridClusteringAlgorithmConfiguration *configuration;
@end

@implementation KPGridClusteringAlgorithm

- (id)init {
    self = [super init];

    if (self == nil) return nil;

    self.configuration = [[KPGridClusteringAlgorithmConfiguration alloc] init];
    
    return self;
}

- (NSArray *)performClusteringOfAnnotationsInMapRect:(MKMapRect)mapRect annotationTree:(KPAnnotationTree *)annotationTree {

    MKMapSize cellSize = [self.delegate gridClusteringAlgorithm:self obtainGridCellSizeForMapRect:mapRect];


    // Normalize grid to a cell size.
    mapRect = MKMapRectNormalizeToCellSize(mapRect, cellSize);


    int gridSizeX = mapRect.size.width / cellSize.width;
    int gridSizeY = mapRect.size.height / cellSize.height;


    __block NSMutableArray *newClusters = [[NSMutableArray alloc] initWithCapacity:(gridSizeX * gridSizeY)];


    kp_cluster_grid_t *clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);


    NSUInteger clusterIndex = 0;

    for(int col = 1; col < (gridSizeY + 1); col++) {
        for(int row = 1; row < (gridSizeX + 1); row++){

            int x = mapRect.origin.x + (row - 1) * cellSize.width;
            int y = mapRect.origin.y + (col - 1) * cellSize.height;

            MKMapRect gridRect = MKMapRectMake(x, y, cellSize.width, cellSize.height);

            NSArray *newAnnotations = [annotationTree annotationsInMapRect:gridRect];

            // cluster annotations in this grid piece, if there are annotations to be clustered
            if (newAnnotations.count > 0) {
                KPAnnotation *annotation = [[KPAnnotation alloc] initWithAnnotations:newAnnotations];
                [newClusters addObject:annotation];

                kp_cluster_t *cluster = clusterGrid->storage + clusterIndex;
                cluster->mapRect = gridRect;
                cluster->annotationIndex = clusterIndex;
                cluster->merged = NO;

                cluster->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(gridRect, MKMapPointForCoordinate(annotation.coordinate));

                clusterGrid->grid[col][row] = cluster;

                clusterIndex++;
            } else {
                clusterGrid->grid[col][row] = NULL;
            }
        }
    }

    if ([self.delegate respondsToSelector:@selector(gridClusteringAlgorithm:clusterIntersects:anotherCluster:)]) {
        newClusters = (NSMutableArray *)[self _mergeOverlappingClusters:newClusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];
    }


    KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);

    
    return newClusters;
}


- (NSArray *)_mergeOverlappingClusters:(NSArray *)clusters inClusterGrid:(kp_cluster_grid_t *)clusterGrid gridSizeX:(NSUInteger)gridSizeX gridSizeY:(NSUInteger)gridSizeY {
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

        BOOL clustersIntersect = [self.delegate gridClusteringAlgorithm:self clusterIntersects:cluster1 anotherCluster:cluster2];

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


    kp_cluster_grid_cell_position_t currentClusterPosition;
    kp_cluster_grid_cell_position_t adjacentClusterPosition;

    kp_cluster_t *currentCellCluster;
    kp_cluster_t *adjacentCellCluster;

    kp_cluster_merge_result_t mergeResult;


    for (uint16_t col = 1; col < (gridSizeY + 2); col++) {
        for (uint16_t row = 1; row < (gridSizeX + 2); row++) {
            loop_with_explicit_col_and_row:

            assert(col > 0);
            assert(row > 0);

            currentClusterPosition.col = col;
            currentClusterPosition.row = row;

            currentCellCluster = clusterGrid->grid[col][row];

            if (currentCellCluster == NULL || currentCellCluster->merged) {
                continue;
            }

            int lookupIndexForCurrentCellQuadrant = log2f(currentCellCluster->distributionQuadrant); // we take log2f, because we need to transform KPClusterDistributionQuadrant which is one of the 1, 2, 4, 8 into array index: 0, 1, 2, 3, which we will use for lookups on the next step

            // Checking adjacent clusters
            for (int adjacentClustersPositionIndex = 0; adjacentClustersPositionIndex < 3; adjacentClustersPositionIndex++) {
                int adjacentClusterLocation = KPClusterAdjacentClusterLocationsTable[lookupIndexForCurrentCellQuadrant][adjacentClustersPositionIndex];

                adjacentClusterPosition.col = currentClusterPosition.col + KPAdjacentClusterPositionDeltas[adjacentClusterLocation][0];
                adjacentClusterPosition.row = currentClusterPosition.row + KPAdjacentClusterPositionDeltas[adjacentClusterLocation][1];

                adjacentCellCluster = clusterGrid->grid[adjacentClusterPosition.col][adjacentClusterPosition.row];

                // In third condition we use bitwise AND ('&') to check if adjacent cell has distribution of its cluster point which is _complementary_ to a one of the current cell. If it is so, than it worth to make a merge check.
                if (adjacentCellCluster != NULL && adjacentCellCluster->merged == NO && (KPClusterConformityTable[adjacentClusterLocation] & adjacentCellCluster->distributionQuadrant) != 0) {
                    mergeResult = checkClustersAndMergeIfNeeded(currentCellCluster, adjacentCellCluster);

                    // The case when other cluster did adsorb current cluster into itself. This means that we must not continue looking for adjacent clusters because we don't have a current cell now.
                    if (mergeResult == KPClusterMergeResultOther) {
                        // If this other cluster lies upstream (behind current i,j cell), we revert back to its [i,j] coordinate and continue looping
                        if (KPClusterGridCellPositionCompareWithPosition(&currentClusterPosition, &adjacentClusterPosition) == NSOrderedDescending) {

                            col = adjacentClusterPosition.col;
                            row = adjacentClusterPosition.row;

                            goto loop_with_explicit_col_and_row;
                        }

                        break; // This breaks from "Checking adjacent clusters"
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
