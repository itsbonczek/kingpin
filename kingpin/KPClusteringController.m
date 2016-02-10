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

#import "KPClusteringController.h"

#import "KPAnnotation.h"
#import "KPAnnotationTree.h"
#import "KPGridClusteringAlgorithm.h"

#import "NSArray+KP.h"

typedef NS_ENUM(NSInteger, KPClusteringControllerMapViewportChangeState) {
    KPClusteringControllerMapViewportNoChange,
    KPClusteringControllerMapViewportPan,
    KPClusteringControllerMapViewportZoom
};


@interface KPClusteringController()

@property (strong, nonatomic) MKMapView *mapView;
@property (strong, nonatomic) KPAnnotationTree *annotationTree;
@property (strong, nonatomic) id <KPClusteringAlgorithm> clusteringAlgorithm;

@property (readonly, nonatomic) NSArray *currentAnnotations;

@property (readonly, nonatomic) MKMapRect clusteringMapRectForVisibleMapRect;
@property (assign, nonatomic)   MKMapRect lastRefreshedMapRect;

@property (assign, nonatomic) MKCoordinateRegion lastRefreshedMapRegion;
@property (assign, readonly, nonatomic) KPClusteringControllerMapViewportChangeState mapViewportChangeState;

- (void)updateVisibleMapAnnotationsOnMapView:(BOOL)animated;
- (void)animateCluster:(KPAnnotation *)cluster
         fromAnnotation:(KPAnnotation *)fromAnnotation
           toAnnotation:(KPAnnotation *)toAnnotation
             completion:(void (^)(BOOL finished))completion;

@end

@implementation KPClusteringController

- (id)initWithMapView:(MKMapView *)mapView
{
    return [self initWithMapView:mapView
             clusteringAlgorithm:[[KPGridClusteringAlgorithm alloc] init]];
            
}

- (id)initWithMapView:(MKMapView *)mapView clusteringAlgorithm:(id<KPClusteringAlgorithm>)algorithm
{
    NSAssert(mapView, @"mapView parameter must not be nil");

    self = [self init];
    
    if (self == nil) {
        return nil;
    }

    self.mapView = mapView;

    self.lastRefreshedMapRect = self.mapView.visibleMapRect;
    self.lastRefreshedMapRegion = self.mapView.region;

    self.animationDuration = 0.5f;
    self.minimalZoomChange = 0.1f;

#if TARGET_OS_IPHONE
    self.animationOptions = UIViewAnimationOptionCurveEaseOut;
#endif

    self.clusteringAlgorithm = algorithm;

    return self;
}

- (NSArray *)currentAnnotations {
    return [self.mapView.annotations kp_filter:^BOOL(id annotation) {
        if ([annotation isKindOfClass:[KPAnnotation class]]) {
            return ([self.annotationTree.annotations containsObject:[[(KPAnnotation*)annotation annotations] anyObject]]);
        }
        else {
            return NO;
        }
    }];
}

- (void)setAnnotations:(NSArray *)annotations {
    [self.mapView removeAnnotations:self.currentAnnotations];

    self.annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    [self updateVisibleMapAnnotationsOnMapView:NO];
}

- (void)refresh:(BOOL)animated {
    [self refresh:animated force:NO];
}


-(void)refresh:(BOOL)animated force:(BOOL)force {
    // Check if map is visible
    if (self.mapView.visibleMapRect.size.width  == 0 ||
        self.mapView.visibleMapRect.size.height == 0) {
        return;
    }

    // If force flag is enabled, don't do any validation with the viewport changes
    if (force) {
        [self updateVisibleMapAnnotationsOnMapView:animated];

        self.lastRefreshedMapRect = self.mapView.visibleMapRect;
        self.lastRefreshedMapRegion = self.mapView.region;
    }

    // Else, check for significant panning or if the map is displayed
    else {
        KPClusteringControllerMapViewportChangeState mapViewportChangeState = self.mapViewportChangeState;

        // Check for signficant viewport changes
        if (mapViewportChangeState != KPClusteringControllerMapViewportNoChange) {
            [self updateVisibleMapAnnotationsOnMapView:(animated && mapViewportChangeState != KPClusteringControllerMapViewportPan)];

            self.lastRefreshedMapRect = self.mapView.visibleMapRect;
            self.lastRefreshedMapRegion = self.mapView.region;
        }
    }
}

// only refresh if:
// - the map has been zoomed
// - the map has been panned significantly
- (KPClusteringControllerMapViewportChangeState)mapViewportChangeState {
    
    if (MKMapRectEqualToRect(self.mapView.visibleMapRect, self.lastRefreshedMapRect)) {
        return KPClusteringControllerMapViewportNoChange;
    }

    if (fabs(self.lastRefreshedMapRect.size.width - self.mapView.visibleMapRect.size.width) > self.minimalZoomChange) {
        return KPClusteringControllerMapViewportZoom;
    }

    CGPoint lastPoint = [self.mapView convertCoordinate:self.lastRefreshedMapRegion.center
                                          toPointToView:self.mapView];

    CGPoint currentPoint = [self.mapView convertCoordinate:self.mapView.region.center
                                             toPointToView:self.mapView];

    if ((fabs(lastPoint.x - currentPoint.x) > self.mapView.frame.size.width) ||
        (fabs(lastPoint.y - currentPoint.y) > self.mapView.frame.size.height)) {
        return KPClusteringControllerMapViewportPan;
    }

    return KPClusteringControllerMapViewportNoChange;
}

- (MKMapRect)clusteringMapRectForVisibleMapRect {
    return MKMapRectInset(self.mapView.visibleMapRect,
                         -self.mapView.visibleMapRect.size.width,
                         -self.mapView.visibleMapRect.size.height);

}

#pragma mark
#pragma mark Private

- (void)updateVisibleMapAnnotationsOnMapView:(BOOL)animated {
    // FIXME: the following if -> drop out is the workaround to prevent kingpin from crashing in
    // applications which have tricky auto-layout enabled
    // In future versions of kingpin this will be replaced with strong prompt about misuse
    // that is being done by a developer
    // Check if map is visible
    if (self.mapView.visibleMapRect.size.width  == 0 ||
        self.mapView.visibleMapRect.size.height == 0) {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(clusteringControllerWillUpdateVisibleAnnotations:)]) {

        [self.delegate clusteringControllerWillUpdateVisibleAnnotations:self];
    }

    MKMapRect clusteringMapRect = self.clusteringMapRectForVisibleMapRect;

    NSArray *newClusters;

    BOOL clusteringEnabled = YES;

    if ([self.delegate respondsToSelector:@selector(clusteringControllerShouldClusterAnnotations:)]) {
        clusteringEnabled = [self.delegate clusteringControllerShouldClusterAnnotations:self];
    }

    if (clusteringEnabled) {
        newClusters = [self.clusteringAlgorithm clusterAnnotationsInMapRect:clusteringMapRect
                                                              parentMapView:self.mapView
                                                             annotationTree:self.annotationTree];
    } else {
        NSArray *newAnnotations = [self.annotationTree annotationsInMapRect:clusteringMapRect];

        newClusters = [newAnnotations kp_map:^id(id annotation) {
            return [[KPAnnotation alloc] initWithAnnotations:@[ annotation ]];
        }];
    }

    if ([self.delegate respondsToSelector:@selector(clusteringController:configureAnnotationForDisplay:)]) {
        for (KPAnnotation *annotation in newClusters) {
            [self.delegate clusteringController:self configureAnnotationForDisplay:annotation];
        }
    }

    NSArray *oldClusters = self.currentAnnotations;

    if (animated) {
        
        NSMutableArray *removedAnnotations = [NSMutableArray arrayWithCapacity:[oldClusters count]];
        
        // dispatch group to fire off callback after mapView has been updated with all new annotations
        dispatch_group_t group = dispatch_group_create();

        NSSet *visibleAnnotations = [self.mapView annotationsInMapRect:self.mapView.visibleMapRect];

        for (KPAnnotation *newCluster in newClusters) {

            [self.mapView addAnnotation:newCluster];

            for (KPAnnotation *oldCluster in oldClusters) {
                
                // if was part of an old cluster, then we want to animate it from the old to the new (spreading animation)
                if ([oldCluster.annotations member:[newCluster.annotations anyObject]]) {
                    BOOL shouldAnimate = [oldCluster.annotations isEqualToSet:newCluster.annotations] == NO;

                    if (shouldAnimate && [visibleAnnotations member:oldCluster]) {
                        
                        dispatch_group_enter(group);

                        [self animateCluster:newCluster
                                          fromAnnotation:oldCluster
                                            toAnnotation:newCluster
                                              completion:^(BOOL finished) {
                                                  dispatch_group_leave(group);
                                              }];
                    }

                    [removedAnnotations addObject:oldCluster];
                }

                // if the new cluster had old annotations, then animate the old annotations to the new one, and remove it
                // (collapsing animation)

                else if ([newCluster.annotations member:[oldCluster.annotations anyObject]]) {
                    
                    BOOL shouldAnimate = [oldCluster.annotations isEqualToSet:newCluster.annotations] == NO;

                    if (shouldAnimate && MKMapRectContainsPoint(self.mapView.visibleMapRect, MKMapPointForCoordinate(newCluster.coordinate))) {

                        dispatch_group_enter(group);

                        [self animateCluster:oldCluster
                                          fromAnnotation:oldCluster
                                            toAnnotation:newCluster
                                              completion:^(BOOL finished) {
                                                  [self.mapView removeAnnotation:oldCluster];

                                                  dispatch_group_leave(group);
                                              }];
                    }

                    else {
                        [removedAnnotations addObject:oldCluster];
                    }
                }
            }
        }
        
        [self.mapView removeAnnotations:removedAnnotations];

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(clusteringControllerDidUpdateVisibleMapAnnotations:)]) {
                [self.delegate clusteringControllerDidUpdateVisibleMapAnnotations:self];
            }
        });
    }

    else {
        [self.mapView removeAnnotations:oldClusters];
        [self.mapView addAnnotations:newClusters];

        if ([self.delegate respondsToSelector:@selector(clusteringControllerDidUpdateVisibleMapAnnotations:)]) {
            [self.delegate clusteringControllerDidUpdateVisibleMapAnnotations:self];
        }
    }
}

- (void)animateCluster:(KPAnnotation *)cluster
         fromAnnotation:(KPAnnotation *)fromAnnotation
           toAnnotation:(KPAnnotation *)toAnnotation
             completion:(void (^)(BOOL finished))completion {

    CLLocationCoordinate2D fromCoord = fromAnnotation.coordinate;
    CLLocationCoordinate2D toCoord = toAnnotation.coordinate;
    
    cluster.coordinate = fromCoord;
    
    if ([self.delegate respondsToSelector:@selector(clusteringController:
                                                    willAnimateAnnotation:
                                                    fromAnnotation:
                                                    toAnnotation:)])
    {
        [self.delegate clusteringController:self
                willAnimateAnnotation:cluster
                       fromAnnotation:fromAnnotation
                         toAnnotation:toAnnotation];
    }
    
    void (^completionDelegate)() = ^ {
        if ([self.delegate respondsToSelector:@selector(clusteringController:
                                                        didAnimateAnnotation:
                                                        fromAnnotation:
                                                        toAnnotation:)])
        {
            [self.delegate clusteringController:self
                     didAnimateAnnotation:cluster
                           fromAnnotation:fromAnnotation
                             toAnnotation:toAnnotation];
        }
    };
    
    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
        completionDelegate();
        
        if (completion) {
            completion(finished);
        }
    };
    [self executeAnimations:^{
        cluster.coordinate = toCoord;
    } completion:completionBlock];
    
}

- (void)executeAnimations:(void(^)(void))animations completion:(void(^)(BOOL finished))completionBlock {
    if ([self.delegate respondsToSelector:@selector(clusteringController:
                                                    performAnimations:
                                                    withCompletionHandler:)]) {
        [self.delegate clusteringController:self
                          performAnimations:animations
                      withCompletionHandler:completionBlock];
    } else {
#if TARGET_OS_IPHONE
        [UIView animateWithDuration:self.animationDuration
                              delay:0
                            options:self.animationOptions
                         animations:animations
                         completion:completionBlock];
#else
        NSAssert(NO, @"Kingpin does not support animations on OSX yet!");

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = self.animationDuration;
            context.allowsImplicitAnimation = YES;

            animations();
        } completionHandler:^{
            if (completionBlock) completionBlock(YES);
        }];
#endif
    }
}

@end
