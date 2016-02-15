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

#import <Foundation/Foundation.h>

#import "KPClusteringAlgorithm.h"

@class KPAnnotation;

@protocol KPClusteringControllerDelegate;

@interface KPClusteringController : NSObject

/// these are ignored if the delegate implements -clusteringController:performAnimations:withCompletionHandler:
@property (assign, nonatomic) CGFloat animationDuration;

/// override the minimum zoom needed to refresh the cluster
@property (assign, nonatomic) CGFloat minimalZoomChange;

#if TARGET_OS_IPHONE
@property (assign, nonatomic) UIViewAnimationOptions animationOptions;
#endif

@property (weak, nonatomic) id <KPClusteringControllerDelegate> delegate;

- (id)initWithMapView:(MKMapView *)mapView;
- (id)initWithMapView:(MKMapView *)mapView clusteringAlgorithm:(id<KPClusteringAlgorithm>)algorithm;
- (void)setAnnotations:(NSArray *)annoations;

/**
 *  Refreshes the map annotations. This will check if the map is visible and if the viewport has changed
 *
 *  @param animated whether the view refresh is animated or not
 */
- (void)refresh:(BOOL)animated;

/**
 *  Refreshes the map annotations. The force flag allows the user to force a refresh even though the viewport
 *  has not significantly moved or if the map is not displayed. For most cases, leave the force flag to NO,
 *  forcing a refresh can be CPU heavy.
 *
 *  @param animated whether the view refresh is animated or not
 *  @param force    YES if you want to force a refresh without checking for viewport change or if the map
 *                  is visible, else NO.
 */
-(void)refresh:(BOOL)animated force:(BOOL)force;

@end


@protocol KPClusteringControllerDelegate <NSObject>

@optional

- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController;

- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation;

- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController;
- (void)clusteringControllerDidUpdateVisibleMapAnnotations:(KPClusteringController *)clusteringController;

- (void)clusteringController:(KPClusteringController *)clusteringController
       willAnimateAnnotation:(KPAnnotation *)annotation
              fromAnnotation:(KPAnnotation *)fromAnntation
                toAnnotation:(KPAnnotation *)toAnnotation;

- (void)clusteringController:(KPClusteringController *)clusteringController
        didAnimateAnnotation:(KPAnnotation *)annotation
              fromAnnotation:(KPAnnotation *)fromAnntation
                toAnnotation:(KPAnnotation *)toAnnotation;

- (void)clusteringController:(KPClusteringController *)clusteringController
           performAnimations:(void(^)())animations
       withCompletionHandler:(void(^)(BOOL finished))completion;

@end
