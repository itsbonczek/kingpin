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

#import <objc/runtime.h>

#import "KPTreeController.h"

#import "KPAnnotation.h"
#import "KPAnnotationTree.h"

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

------ -------- --------
      |        |        |
 cl.3 |  cl.2  |  cl.1  |
      |        |        |
------ -------- --------
      |  2   1 |        |
 cl.4 | current|  cl.0  |  // the middle cell is the every current cluster in -mergeOverlappingClusters
      |  3   4 |        |
------ -------- --------
      |        |        |
 cl.5 |  cl.6  |  cl.7  |
      |        |        |
------ -------- --------
 */
static const int KPClusterAdjacentClustersTable[4][3] = {
    {0, 1, 2},
    {2, 3, 4},
    {4, 5, 6},
    {6, 7, 0},
};

static const int KPAdjacentClustersCoordinateDeltas[8][2] = {
    { 1,  0},    // 0 means that to access coordinate of cell #0 (to the right from current i, j) we must add the following: i + 1, j + 0
    { 1, -1},    // 1
    { 0, -1},    // 2
    {-1, -1},    // 3
    {-1,  0},    // 4
    {-1,  1},    // 5
    { 0,  1},    // 6
    { 1,  1}     // 7
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


@interface KPTreeController()

@property (nonatomic) MKMapView *mapView;
@property (nonatomic) KPAnnotationTree *annotationTree;
@property (nonatomic) MKMapRect lastRefreshedMapRect;
@property (nonatomic) MKCoordinateRegion lastRefreshedMapRegion;
@property (nonatomic) CGRect mapFrame;
@property (nonatomic, readwrite) NSArray *gridPolylines;

@end

@implementation KPTreeController

- (id)initWithMapView:(MKMapView *)mapView {
    
    self = [super init];
    
    if(self){
        self.mapView = mapView;
        self.mapFrame = self.mapView.frame;
        self.gridSize = CGSizeMake(60.f, 60.f);
        self.annotationSize = CGSizeMake(60, 60);
        self.annotationCenterOffset = CGPointMake(30.f, 30.f);
        self.animationDuration = 0.5f;
        self.clusteringEnabled = YES;
    }
    
    return self;
    
}

- (void)setAnnotations:(NSArray *)annotations {
    NSArray *mapAnnotations = self.mapView.annotations;

    NSIndexSet *removeIndexes = [mapAnnotations indexesOfObjectsPassingTest:^BOOL(id annotation, NSUInteger idx, BOOL *stop) {
        if ([annotation isKindOfClass:[KPAnnotation class]]) {
            return ([self.annotationTree.annotations containsObject:[[(KPAnnotation *)annotation annotations] anyObject]]);
        } else {
            return NO;
        }
    }];

    [self.mapView removeAnnotations:[mapAnnotations objectsAtIndexes:removeIndexes]];

    self.annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    [self _updateVisibileMapAnnotationsOnMapView:NO];
}

- (void)refresh:(BOOL)animated {
    
    if(MKMapRectIsNull(self.lastRefreshedMapRect) || [self _mapWasZoomed] || [self _mapWasPannedSignificantly]){
        [self _updateVisibileMapAnnotationsOnMapView:animated && [self _mapWasZoomed]];
        self.lastRefreshedMapRect = self.mapView.visibleMapRect;
        self.lastRefreshedMapRegion = self.mapView.region;
    }
}

// only refresh if:
// - the map has been zoomed
// - the map has been panned significantly

- (BOOL)_mapWasZoomed {
    return (fabs(self.lastRefreshedMapRect.size.width - self.mapView.visibleMapRect.size.width) > 0.1f);
}

- (BOOL)_mapWasPannedSignificantly {
    CGPoint lastPoint = [self.mapView convertCoordinate:self.lastRefreshedMapRegion.center
                                          toPointToView:self.mapView];
    
    CGPoint currentPoint = [self.mapView convertCoordinate:self.mapView.region.center
                                             toPointToView:self.mapView];

    return
    (fabs(lastPoint.x - currentPoint.x) > self.mapFrame.size.width) ||
    (fabs(lastPoint.y - currentPoint.y) > self.mapFrame.size.height);
}


#pragma mark - Private

- (void)_updateVisibileMapAnnotationsOnMapView:(BOOL)animated
{
    NSSet *visibleAnnotations = [self.mapView annotationsInMapRect:[self.mapView visibleMapRect]];
    
    // updates visible map rect plus a map view's worth of padding around it
    MKMapRect bigRect = MKMapRectInset(self.mapView.visibleMapRect,
                                       -self.mapView.visibleMapRect.size.width,
                                       -self.mapView.visibleMapRect.size.height);
    
    if (MKMapRectGetHeight(bigRect) > MKMapRectGetHeight(MKMapRectWorld) ||
        MKMapRectGetWidth(bigRect) > MKMapRectGetWidth(MKMapRectWorld)) {
        bigRect = MKMapRectWorld;
    }
    
    
    // calculate the grid size in terms of MKMapPoints
    double widthPercentage = self.gridSize.width / CGRectGetWidth(self.mapView.frame);
    double heightPercentage = self.gridSize.height / CGRectGetHeight(self.mapView.frame);
    
    double widthInterval = ceil(widthPercentage * self.mapView.visibleMapRect.size.width);
    double heightInterval = ceil(heightPercentage * self.mapView.visibleMapRect.size.height);


    // Normalize rect to a cell size
    bigRect.origin.x -= fmod(MKMapRectGetMinX(bigRect), widthInterval);
    bigRect.origin.y -= fmod(MKMapRectGetMinY(bigRect), heightInterval);

    bigRect.size.width += (widthInterval - fmod(MKMapRectGetWidth(bigRect), widthInterval));
    bigRect.size.height += (heightInterval - fmod(MKMapRectGetHeight(bigRect), heightInterval));

    int gridSizeX = bigRect.size.width / widthInterval;
    int gridSizeY = bigRect.size.height / heightInterval;

    // we initialize with a rough estimate for size, as to minimize allocations
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
    kp_cluster_t ***clusterGrid = malloc((gridSizeX + 2) * sizeof(kp_cluster_t **));
    for (int i = 0; i < gridSizeX + 2; i++) {
        clusterGrid[i] = malloc((gridSizeY + 2) * sizeof(kp_cluster_t *));

        // First and last elements are marginal NULL
        clusterGrid[i][0] = NULL;
        clusterGrid[i][gridSizeY + 1] = NULL;
    }

    // memset is the fastest way to NULLify marginal first and last rows of clusterGrid
    memset(clusterGrid[0],             0, (gridSizeY + 2) * sizeof(kp_cluster_t *));
    memset(clusterGrid[gridSizeX + 1], 0, (gridSizeY + 2) * sizeof(kp_cluster_t *));

    /* Validation (Debug, remove later) */
    for (int i = 0; i < gridSizeX + 2; i++) {
        assert(clusterGrid[i][0] == NULL);
        assert(clusterGrid[i][gridSizeY + 1] == NULL);
    }
    for (int i = 0; i < gridSizeY + 2; i++) {
        assert(clusterGrid[0][i] == NULL);
        assert(clusterGrid[gridSizeX + 1][0] == NULL);
    }

    NSMutableArray *polylines = nil;
    
    if (self.debuggingEnabled) {
        polylines = [NSMutableArray new];
    }

    NSUInteger clusterIndex = 0;

    NSUInteger counter = 0;
    for(int i = 1; i < (gridSizeX + 1); i++) {
        for(int j = 1; j < (gridSizeY + 1); j++){
            counter++;

            int x = bigRect.origin.x + i * widthInterval;
            int y = bigRect.origin.y + j * heightInterval;

            MKMapRect gridRect = MKMapRectMake(x, y, widthInterval, heightInterval);

            NSArray *newAnnotations = [self.annotationTree annotationsInMapRect:gridRect];

            // cluster annotations in this grid piece, if there are annotations to be clustered
            if (newAnnotations.count > 0) {
                
                // if clustering is disabled, add each annotation individually

                if (self.clusteringEnabled) {
                    KPAnnotation *annotation = [[KPAnnotation alloc] initWithAnnotations:newAnnotations];
                    [newClusters addObject:annotation];

                    kp_cluster_t *cluster = clusterStorage + clusterIndex;
                    cluster->mapRect = gridRect;
                    cluster->annotationIndex = clusterIndex;
                    cluster->merged = NO;

                    cluster->distributionQuadrant = KPClusterDistributionQuadrantForPointInsideMapRect(gridRect, MKMapPointForCoordinate(annotation.coordinate));

                    clusterGrid[i][j] = cluster;

                    clusterIndex++;
                }
                else {
                    NSMutableArray *clustersToAdd = [NSMutableArray new];

                    [clustersToAdd addObjectsFromArray:[newAnnotations kp_map:^KPAnnotation *(id<MKAnnotation> a) {
                        return [[KPAnnotation alloc] initWithAnnotations:@[a]];
                    }]];

                    [newClusters addObjectsFromArray:clustersToAdd];
                }
            } else {
                if (self.clusteringEnabled) {
                    clusterGrid[i][j] = NULL;
                }
            }
            
            if (self.debuggingEnabled) {

                MKMapPoint points[5];
                points[0] = MKMapPointMake(x, y);
                points[1] = MKMapPointMake(x + widthInterval, y);
                points[2] = MKMapPointMake(x + widthInterval, y + heightInterval);
                points[3] = MKMapPointMake(x, y + heightInterval);
                points[4] = MKMapPointMake(x, y);
                
                [polylines addObject:[MKPolyline polylineWithPoints:points count:5]];
                
            }
        }
    }

    /* Validation (Debug, remove later) */
    assert(counter == (gridSizeX * gridSizeY));

    /* Validation (Debug, remove later) */
    for(int i = 0; i < gridSizeX; i++){
        for(int j = 0; j < gridSizeY; j++){
            kp_cluster_t *cluster = clusterGrid[i][j];

            if (cluster) {
                assert(cluster->merged == NO);
                assert(cluster->annotationIndex >= 0);
                assert(cluster->annotationIndex < gridSizeX * gridSizeY);
            }
        }
    }

    if (self.debuggingEnabled) {
        self.gridPolylines = polylines;
    }

    if (self.clusteringEnabled) {
        newClusters = (NSMutableArray *)[self _mergeOverlappingClusters:newClusters inClusterGrid:clusterGrid gridSizeX:gridSizeX gridSizeY:gridSizeY];
    }

    if ([self.delegate respondsToSelector:@selector(treeController:configureAnnotationForDisplay:)]) {
        for (KPAnnotation *annotation in newClusters){
                [self.delegate treeController:self configureAnnotationForDisplay:annotation];
        }
    }

    for (int i = 0; i < (gridSizeX + 2); i++) {
        free(clusterGrid[i]);
    }
    free(clusterGrid);
    free(clusterStorage);

    NSArray *oldClusters = [self.mapView.annotations kp_filter:^BOOL(id annotation) {
        if ([annotation isKindOfClass:[KPAnnotation class]]) {
            return ([self.annotationTree.annotations containsObject:[[(KPAnnotation *)annotation annotations] anyObject]]);
        } else {
            return NO;
        }
    }];

    if (animated) {
        
        for(KPAnnotation *newCluster in newClusters){
            
            [self.mapView addAnnotation:newCluster];
            
            // if was part of an old cluster, then we want to animate it from the old to the new (spreading animation)
            
            for(KPAnnotation *oldCluster in oldClusters){
                
                BOOL shouldAnimate = ![oldCluster.annotations isEqualToSet:newCluster.annotations];
                
                if([oldCluster.annotations member:[newCluster.annotations anyObject]]){
                    
                    if([visibleAnnotations member:oldCluster] && shouldAnimate){
                        [self _animateCluster:newCluster
                               fromAnnotation:oldCluster
                                 toAnnotation:newCluster
                                   completion:nil];
                    }
                    
                    [self.mapView removeAnnotation:oldCluster];
                }
                
                // if the new cluster had old annotations, then animate the old annotations to the new one, and remove it
                // (collapsing animation)
                
                else if([newCluster.annotations member:[oldCluster.annotations anyObject]]){
                    
                    if(MKMapRectContainsPoint(self.mapView.visibleMapRect, MKMapPointForCoordinate(newCluster.coordinate)) && shouldAnimate){
                        
                        [self _animateCluster:oldCluster
                               fromAnnotation:oldCluster
                                 toAnnotation:newCluster
                                   completion:^(BOOL finished) {
                                       [self.mapView removeAnnotation:oldCluster];
                                   }];
                    }
                    else {
                        [self.mapView removeAnnotation:oldCluster];
                    }
                    
                }
            }
        }

    }
    else {
        [self.mapView removeAnnotations:oldClusters];
        [self.mapView addAnnotations:newClusters];
    }
        
}

- (void)_animateCluster:(KPAnnotation *)cluster
         fromAnnotation:(KPAnnotation *)fromAnnotation
           toAnnotation:(KPAnnotation *)toAnnotation
             completion:(void (^)(BOOL finished))completion
{
    
    CLLocationCoordinate2D fromCoord = fromAnnotation.coordinate;
    CLLocationCoordinate2D toCoord = toAnnotation.coordinate;
    
    cluster.coordinate = fromCoord;
    
    if ([self.delegate respondsToSelector:@selector(treeController:willAnimateAnnotation:fromAnnotation:toAnnotation:)]) {
        [self.delegate treeController:self willAnimateAnnotation:cluster fromAnnotation:fromAnnotation toAnnotation:toAnnotation];
    }
    
    void (^completionDelegate)() = ^ {
        if ([self.delegate respondsToSelector:@selector(treeController:didAnimateAnnotation:fromAnnotation:toAnnotation:)]) {
            [self.delegate treeController:self didAnimateAnnotation:cluster fromAnnotation:fromAnnotation toAnnotation:toAnnotation];
        }
    };
    
    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {

        completionDelegate();
        
        if (completion) {
            completion(finished);
        }
    };
    
    [UIView animateWithDuration:self.animationDuration
                          delay:0.f
                        options:self.animationOptions
                     animations:^{
                         cluster.coordinate = toCoord;
                     }
                     completion:completionBlock];
    
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


        // calculate CGRects for each annotation, memoizing the coord -> point conversion as we go
        // if the two views overlap, merge them

        if (cluster1._annotationPointInMapView == nil) {
            cluster1._annotationPointInMapView = [NSValue valueWithCGPoint:[self.mapView convertCoordinate:cluster1.coordinate
                                                                                       toPointToView:self.mapView]];
        }

        if (cluster2._annotationPointInMapView == nil) {
            cluster2._annotationPointInMapView = [NSValue valueWithCGPoint:[self.mapView convertCoordinate:cluster2.coordinate
                                                                                       toPointToView:self.mapView]];
        }

        CGPoint p1 = [cluster1._annotationPointInMapView CGPointValue];
        CGPoint p2 = [cluster2._annotationPointInMapView CGPointValue];

        CGRect r1 = CGRectMake(p1.x - self.annotationSize.width + self.annotationCenterOffset.x,
                               p1.y - self.annotationSize.height + self.annotationCenterOffset.y,
                               self.annotationSize.width,
                               self.annotationSize.height);

        CGRect r2 = CGRectMake(p2.x - self.annotationSize.width + self.annotationCenterOffset.x,
                               p2.y - self.annotationSize.height + self.annotationCenterOffset.y,
                               self.annotationSize.width,
                               self.annotationSize.height);

        if (CGRectIntersectsRect(r1, r2)) {
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


    int currentClusterCoordinate[2];
    int adjacentClusterCoordinate[2];

    kp_cluster_t *currentCellCluster;
    kp_cluster_t *adjacentCellCluster;

    kp_cluster_merge_result_t mergeResult;


    for (int16_t j = 1; j < gridSizeY + 2; j++) {
        for (int16_t i = 1; i < gridSizeX + 2; i++) {
            loop_with_explicit_i_and_j:

            assert(i >= 0);
            assert(j >= 0);

            currentClusterCoordinate[0] = i;
            currentClusterCoordinate[1] = j;

            currentCellCluster = clusterGrid[i][j];

            if (currentCellCluster == NULL || currentCellCluster->merged) {
                continue;
            }

            int lookupIndexForCurrentCellQuadrant = log2f(currentCellCluster->distributionQuadrant); // we take log2f, because we need to transform KPClusterDistributionQuadrant which is one of the 1, 2, 4, 8 into array index: 0, 1, 2, 3, which we will use for lookups on the next step

            for (int adjacentClustersPositionIndex = 0; adjacentClustersPositionIndex < 3; adjacentClustersPositionIndex++) {
                int adjacentClusterPosition = KPClusterAdjacentClustersTable[lookupIndexForCurrentCellQuadrant][adjacentClustersPositionIndex];

                adjacentClusterCoordinate[0] = currentClusterCoordinate[0] + KPAdjacentClustersCoordinateDeltas[adjacentClusterPosition][0];
                adjacentClusterCoordinate[1] = currentClusterCoordinate[1] + KPAdjacentClustersCoordinateDeltas[adjacentClusterPosition][1];

                adjacentCellCluster = clusterGrid[adjacentClusterCoordinate[0]][adjacentClusterCoordinate[1]];

                // In third condition we use bitwise & to check if adjacent cell has distribution of its cluster point which is _complementary_ to a one of the current cell. If it is so, than it worth to make a merge check.
                if (adjacentCellCluster != NULL && adjacentCellCluster->merged == NO && (KPClusterConformityTable[adjacentClusterPosition] & adjacentCellCluster->distributionQuadrant) != 0) {
                    mergeResult = checkClustersAndMergeIfNeeded(currentCellCluster, adjacentCellCluster);

                    // The case when other cluster did adsorb current cluster into itself. This means that we must not continue looking for adjacent clusters because we don't have a current cell now.
                    if (mergeResult == KPClusterMergeResultOther) {
                        // If this other cluster lies upstream (behind current i,j cell), we revert back to its [i,j] coordinate and continue looping
                        if (*(int32_t *)currentClusterCoordinate > *(int32_t *)adjacentClusterCoordinate) {

                            i = adjacentClusterCoordinate[0];
                            j = adjacentClusterCoordinate[1];

                            goto loop_with_explicit_i_and_j;
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
