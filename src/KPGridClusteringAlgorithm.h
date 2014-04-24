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


@class KPAnnotation,
       KPAnnotationTree;

@protocol KPGridClusteringAlgorithmDelegate;


@interface KPGridClusteringAlgorithmConfiguration : NSObject

@property (assign, nonatomic) CGSize gridSize;

@end



@interface KPGridClusteringAlgorithm : NSObject

@property (strong, readonly, nonatomic) KPGridClusteringAlgorithmConfiguration *configuration;

@property (weak, nonatomic) id <KPGridClusteringAlgorithmDelegate> delegate;

- (NSArray *)performClusteringOfAnnotationsInMapRect:(MKMapRect)mapRect mapView:(MKMapView *)mapView annotationTree:(KPAnnotationTree *)annotationTree;

@end