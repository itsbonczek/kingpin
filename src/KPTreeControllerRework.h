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

#import "KPConfiguration.h"

#import "KPGridClusteringAlgorithmDelegate.h"

@class KPAnnotation, KPConfiguration, KPGridClusteringAlgorithm;

@protocol KPTreeControllerReworkDelegate, KPGridClusteringAlgorithmDelegate;

@interface KPTreeControllerRework : NSObject <KPGridClusteringAlgorithmDelegate>

@property (readonly) KPConfiguration *configuration;

@property (weak, nonatomic) id <KPTreeControllerReworkDelegate> delegate;

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

- (BOOL)treeControllerShouldClusterAnnotations:(KPTreeControllerRework *)tree;

- (void)treeController:(KPTreeControllerRework *)tree configureAnnotationForDisplay:(KPAnnotation *)annotation;
- (void)treeController:(KPTreeControllerRework *)tree willAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;
- (void)treeController:(KPTreeControllerRework *)tree didAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;

@end
