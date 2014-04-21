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

#import "KPGridClusteringAlgorithmDelegate.h"

@class KPAnnotation, KPGridClusteringAlgorithm;

@protocol KPTreeControllerReworkDelegate, KPGridClusteringAlgorithmDelegate;

typedef struct {
    CGSize gridSize;
    CGSize annotationSize;
    CGPoint annotationCenterOffset;
    CGFloat animationDuration;
    UIViewAnimationOptions animationOptions;
    BOOL clusteringEnabled;
} KPTreeControllerReworkConfiguration;

@interface KPTreeControllerRework : NSObject <KPGridClusteringAlgorithmDelegate>

@property (nonatomic, weak) id <KPTreeControllerReworkDelegate> delegate;
@property (nonatomic, assign) KPTreeControllerReworkConfiguration configuration;

- (id)initWithMapView:(MKMapView *)mapView;
- (void)setAnnotations:(NSArray *)annoations;
- (void)refresh:(BOOL)animated;

- (void)_animateCluster:(KPAnnotation *)cluster
         fromAnnotation:(KPAnnotation *)fromAnnotation
           toAnnotation:(KPAnnotation *)toAnnotation
             completion:(void (^)(BOOL finished))completion;

@end

@protocol KPTreeControllerReworkDelegate <NSObject>

@optional

- (void)treeController:(KPTreeControllerRework *)tree configureAnnotationForDisplay:(KPAnnotation *)annotation;
- (void)treeController:(KPTreeControllerRework *)tree willAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;
- (void)treeController:(KPTreeControllerRework *)tree didAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;

@end
