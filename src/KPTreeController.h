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


@class KPAnnotation,
       KPGridClusteringAlgorithm;

@protocol KPTreeControllerDelegate,
          KPGridClusteringAlgorithmDelegate;


@interface KPTreeControllerConfiguration : NSObject

@property (assign, nonatomic) CGSize annotationSize;
@property (assign, nonatomic) CGPoint annotationCenterOffset;
@property (assign, nonatomic) CGFloat animationDuration;
@property (assign, nonatomic) UIViewAnimationOptions animationOptions;

@end

@interface KPTreeController : NSObject <KPGridClusteringAlgorithmDelegate>

@property (strong, readonly, nonatomic) KPTreeControllerConfiguration *configuration;

@property (weak, nonatomic) id <KPTreeControllerDelegate> delegate;

- (id)initWithMapView:(MKMapView *)mapView;
- (void)setAnnotations:(NSArray *)annoations;
- (void)refresh:(BOOL)animated;

@end

@protocol KPTreeControllerDelegate <NSObject>

@optional

- (BOOL)treeControllerShouldClusterAnnotations:(KPTreeController *)treeController;

- (void)treeController:(KPTreeController *)treeController configureAnnotationForDisplay:(KPAnnotation *)annotation;
- (void)treeController:(KPTreeController *)treeController willAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;
- (void)treeController:(KPTreeController *)treeController didAnimateAnnotation:(KPAnnotation *)annotation fromAnnotation:(KPAnnotation *)fromAnntation toAnnotation:(KPAnnotation *)toAnnotation;

@end
