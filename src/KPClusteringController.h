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

@property (assign, nonatomic) CGFloat animationDuration;
@property (assign, nonatomic) UIViewAnimationOptions animationOptions;

@property (weak, nonatomic) id <KPClusteringControllerDelegate> delegate;

- (id)initWithMapView:(MKMapView *)mapView;
- (id)initWithMapView:(MKMapView *)mapView clusteringAlgorithm:(id<KPClusteringAlgorithm>)algorithm;
- (void)setAnnotations:(NSArray *)annoations;
- (void)refresh:(BOOL)animated;

@end


@protocol KPClusteringControllerDelegate <NSObject>

@optional

- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController;

- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation;

- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController;

- (void)clusteringController:(KPClusteringController *)clusteringController
       willAnimateAnnotation:(KPAnnotation *)annotation
              fromAnnotation:(KPAnnotation *)fromAnntation
                toAnnotation:(KPAnnotation *)toAnnotation;

- (void)clusteringController:(KPClusteringController *)clusteringController
        didAnimateAnnotation:(KPAnnotation *)annotation
              fromAnnotation:(KPAnnotation *)fromAnntation
                toAnnotation:(KPAnnotation *)toAnnotation;

@end
