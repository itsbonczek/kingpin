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
#import <MapKit/MKAnnotation.h>

@interface KPAnnotation : NSObject <MKAnnotation>

@property (assign, nonatomic) CLLocationCoordinate2D coordinate;
@property (assign, readonly, nonatomic) CLLocationDistance radius;

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;

@property (strong, readonly, nonatomic) NSSet *annotations;

- (id)initWithAnnotations:(NSArray *)annotations;
- (id)initWithAnnotationSet:(NSSet *)set;

// returns NO if the KPAnnotation only contains one annotation
- (BOOL)isCluster;

// Private (used by the internal clustering algorithm)
@property (strong, nonatomic) NSValue *_annotationPointInMapView;

@end
