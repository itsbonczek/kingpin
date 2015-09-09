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

#import "KPAnnotationTree.h"
#import "KPAnnotation.h"

#import "KPGeometry.h"

#import "NSArray+KP.h"

static NSValue *NSValueFromCGPoint(CGPoint point) {
    NSValue *value;

#if TARGET_OS_IPHONE
    value= [NSValue valueWithCGPoint: point];
#else
    value= [NSValue valueWithPoint: point];
#endif

    return value;
}

static CGPoint CGPointFromNSValue(NSValue *value) {
    CGPoint point;

#if TARGET_OS_IPHONE
    point = value.CGPointValue;
#else
    point = value.pointValue;
#endif

    return point;
}

@implementation KPGridClusteringAlgorithm

- (id)init {
    
    if ((self = [super init])) {
        self.clusteringStrategy = KPGridClusteringAlgorithmStrategyBasic;
        self.gridSize = CGSizeMake(60.f, 60.f);
    }
    
    return self;
}

#pragma mark - KPGridClusteringAlgorithm

- (NSArray *)clusterAnnotationsInMapRect:(MKMapRect)mapRect
                           parentMapView:(MKMapView *)mapView
                          annotationTree:(KPAnnotationTree *)annotationTree
{
    [self _ensureStrategyIntegrity];
    
    MKMapSize mapCellSize = [self mapCellSizeForGridSize:self.gridSize inMapView:mapView];

    // Normalize grid to a cell size.
    mapRect = MKMapRectNormalizeToCellSize(mapRect, mapCellSize);

    NSUInteger gridSizeX = mapRect.size.width  / mapCellSize.width;
    NSUInteger gridSizeY = mapRect.size.height / mapCellSize.height;

    __block NSMutableArray *newClusters = [[NSMutableArray alloc] initWithCapacity:(gridSizeX * gridSizeY)];

    kp_cluster_t **clusterGrid = KPClusterGridCreate(gridSizeX, gridSizeY);

    NSUInteger clusterIndex = 0;

    for (NSUInteger col = 1; col < (gridSizeY + 1); col++) {
        for (NSUInteger row = 1; row < (gridSizeX + 1); row++) {
            double x = mapRect.origin.x + (row - 1) * mapCellSize.width;
            double y = mapRect.origin.y + (col - 1) * mapCellSize.height;

            MKMapRect gridRect = MKMapRectMake(x, y, mapCellSize.width, mapCellSize.height);

            NSArray *newAnnotations = [annotationTree annotationsInMapRect:gridRect];

            // cluster annotations in this grid piece, if there are annotations to be clustered
            if (newAnnotations.count > 0) {
                
                id annotation = [[KPAnnotation alloc] initWithAnnotations:newAnnotations];
                [newClusters addObject:annotation];

                kp_cluster_t *cluster = clusterGrid[col] + row;
                
                cluster->mapRect = gridRect;
                cluster->annotationIndex = clusterIndex;
                cluster->state = KPClusterStateHasData;

                cluster->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(gridRect, MKMapPointForCoordinate([annotation coordinate]));

                clusterIndex++;
            } else {
                clusterGrid[col][row].state = KPClusterStateEmpty;
            }
        }
    }
    
    if (self.clusteringStrategy == KPGridClusteringAlgorithmStrategyTwoPhase) {
        
        newClusters = (NSMutableArray *)[self _mergeOverlappingClusters:newClusters
                                                              inMapView:mapView
                                                            clusterGrid:clusterGrid
                                                              gridSizeX:gridSizeX
                                                              gridSizeY:gridSizeY];
    }

    KPClusterGridFree(clusterGrid, gridSizeX, gridSizeY);
    return newClusters;
}

#pragma mark - Private

- (MKMapSize)mapCellSizeForGridSize:(CGSize)gridSize inMapView:(MKMapView *)mapView {
    // Calculate the grid size in terms of MKMapPoints.
    double widthPercentage =  gridSize.width / CGRectGetWidth(mapView.frame);
    double heightPercentage = gridSize.height / CGRectGetHeight(mapView.frame);

    MKMapSize cellSize = MKMapSizeMake(
                                       ceil(widthPercentage  * mapView.visibleMapRect.size.width),
                                       ceil(heightPercentage * mapView.visibleMapRect.size.height)
                                       );

    return cellSize;
}

- (void)_ensureStrategyIntegrity {
    if (self.clusteringStrategy == KPGridClusteringAlgorithmStrategyTwoPhase &&
        CGSizeEqualToSize(self.annotationSize, CGSizeZero)) {
        NSString *failureReason = @"annotationSize must be set when using two phase strategy";

        @throw [NSException exceptionWithName:NSGenericException reason:failureReason userInfo:nil];
    }
}

- (NSArray *)_mergeOverlappingClusters:(NSArray *)clusters
                             inMapView:(MKMapView *)mapView
                           clusterGrid:(kp_cluster_t **)clusterGrid
                             gridSizeX:(NSUInteger)gridSizeX
                             gridSizeY:(NSUInteger)gridSizeY

{
    
    __block NSMutableArray *mutableClusters = [NSMutableArray arrayWithArray:clusters];
    __block NSMutableIndexSet *indexesOfClustersToBeRemovedAsMerged = [NSMutableIndexSet indexSet];
    
    kp_cluster_merge_block_t checkClustersAndMergeIfNeeded = ^(kp_cluster_t *cl1, kp_cluster_t *cl2) {

        NSCAssert(cl1 && cl1->state == KPClusterStateHasData, nil);
        NSCAssert(cl2 && cl2->state == KPClusterStateHasData, nil);

        NSCAssert(cl1->annotationIndex >= 0 && cl1->annotationIndex < gridSizeX * gridSizeY, nil);
        NSCAssert(cl2->annotationIndex >= 0 && cl2->annotationIndex < gridSizeX * gridSizeY, nil);

        KPAnnotation *cluster1 = [mutableClusters objectAtIndex:cl1->annotationIndex];
        KPAnnotation *cluster2 = [mutableClusters objectAtIndex:cl2->annotationIndex];
        
        BOOL clustersIntersect = [self clusterIntersects:cluster1 anotherCluster:cluster2 inMapView:mapView];
        
        if (clustersIntersect) {
            NSMutableSet *combinedSet = [NSMutableSet setWithSet:cluster1.annotations];
            [combinedSet unionSet:cluster2.annotations];
            
            KPAnnotation *newAnnotation = [[KPAnnotation alloc] initWithAnnotationSet:combinedSet];
            
            MKMapPoint newClusterMapPoint = MKMapPointForCoordinate(newAnnotation.coordinate);
            
            if (MKMapRectContainsPoint(cl1->mapRect, newClusterMapPoint)) {
                [indexesOfClustersToBeRemovedAsMerged addIndex:cl2->annotationIndex];

                cl2->state = KPClusterStateMerged;

                mutableClusters[cl1->annotationIndex] = newAnnotation;
                
                cl1->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(cl1->mapRect, newClusterMapPoint);
                
                return KPClusterMergeResultCurrent;
            } else {
                [indexesOfClustersToBeRemovedAsMerged addIndex:cl1->annotationIndex];
                cl1->state = KPClusterStateMerged;

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
    
    KPClusterMergeResult mergeResult;

    for (uint16_t col = 1; col < (gridSizeY + 2); col++) {
        for (uint16_t row = 1; row < (gridSizeX + 2); row++) {
        loop_with_explicit_col_and_row:
            
            NSCAssert(col > 0, nil);
            NSCAssert(row > 0, nil);
            
            currentClusterPosition.col = col;
            currentClusterPosition.row = row;

            currentCellCluster = clusterGrid[col] + row;

            if (currentCellCluster->state != KPClusterStateHasData) {
                continue;
            }
            
            // we take log2f, because we need to transform KPClusterDistributionQuadrant which is one of the
            // 1, 2, 4, 8 into array index: 0, 1, 2, 3, which we will use for lookups on the next step
            int lookupIndexForCurrentCellQuadrant = log2f(currentCellCluster->distributionQuadrant);
            
            // Checking adjacent clusters
            for (int adjacentClustersPositionIndex = 0; adjacentClustersPositionIndex < 3; adjacentClustersPositionIndex++) {
                int adjacentClusterLocation = KPClusterAdjacentClusterLocationsTable[lookupIndexForCurrentCellQuadrant][adjacentClustersPositionIndex];
                
                adjacentClusterPosition.col = currentClusterPosition.col + KPAdjacentClusterPositionDeltas[adjacentClusterLocation][0];
                adjacentClusterPosition.row = currentClusterPosition.row + KPAdjacentClusterPositionDeltas[adjacentClusterLocation][1];

                adjacentCellCluster = clusterGrid[adjacentClusterPosition.col] + adjacentClusterPosition.row;

                // In third condition we use bitwise AND ('&') to check if adjacent cell has distribution of its cluster point which is _complementary_ to a one of the current cell. If it is so, than it worth to make a merge check.
                if (adjacentCellCluster->state == KPClusterStateHasData && (KPClusterConformityTable[adjacentClusterLocation] & adjacentCellCluster->distributionQuadrant) != 0) {
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

- (BOOL)clusterIntersects:(KPAnnotation *)clusterAnnotation
           anotherCluster:(KPAnnotation *)anotherClusterAnnotation
                inMapView:(MKMapView *)mapView
{
    
    // calculate CGRects for each annotation, memoizing the coord -> point conversion as we go
    // if the two views overlap, merge them
    
    if (clusterAnnotation._annotationPointInMapView == nil) {
        clusterAnnotation._annotationPointInMapView = NSValueFromCGPoint([mapView convertCoordinate:clusterAnnotation.coordinate
                                                                                             toPointToView:mapView]);
    }
    
    if (anotherClusterAnnotation._annotationPointInMapView == nil) {
        anotherClusterAnnotation._annotationPointInMapView = NSValueFromCGPoint([mapView convertCoordinate:anotherClusterAnnotation.coordinate
                                                                                                    toPointToView:mapView]);
    }
    
    CGPoint p1 = CGPointFromNSValue(clusterAnnotation._annotationPointInMapView);
    CGPoint p2 = CGPointFromNSValue(anotherClusterAnnotation._annotationPointInMapView);
    
    CGRect r1 = CGRectMake(
                           p1.x - self.annotationSize.width + self.annotationCenterOffset.x,
                           p1.y - self.annotationSize.height + self.annotationCenterOffset.y,
                           self.annotationSize.width,
                           self.annotationSize.height
                           );
    
    CGRect r2 = CGRectMake(
                           p2.x - self.annotationSize.width + self.annotationCenterOffset.x,
                           p2.y - self.annotationSize.height + self.annotationCenterOffset.y,
                           self.annotationSize.width,
                           self.annotationSize.height
                           );
    
    return CGRectIntersectsRect(r1, r2);
}

@end
