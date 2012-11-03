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

#import "KPAnnotation.h"

@interface KPAnnotation ()

@property (nonatomic, readwrite) NSSet *annotations;
@property (nonatomic, readwrite) float radius;

@end

@implementation KPAnnotation


- (id)initWithAnnotations:(NSArray *)annotations {
    
    self = [super init];
    
    if(self){
        self.annotations = [NSSet setWithArray:annotations];
        [self calculateValues];
    }
    
    return self;
}


- (NSString *)title {
    return [NSString stringWithFormat:@"%i things", [self.annotations count]];
}

#pragma mark - Private

- (void)calculateValues {
    
    CLLocationDegrees minLat = INT_MAX;
    CLLocationDegrees minLng = INT_MAX;
    CLLocationDegrees maxLat = -INT_MAX;
    CLLocationDegrees maxLng = -INT_MAX;
    
    for(id<MKAnnotation> a in self.annotations){
        
        CLLocationDegrees lat = [a coordinate].latitude;
        CLLocationDegrees lng = [a coordinate].longitude;
        
        minLat = MIN(minLat, lat);
        minLng = MIN(minLng, lng);
        maxLat = MAX(maxLat, lat);
        maxLng = MAX(maxLng, lng);
    }
    
    
    self.coordinate = [[self.annotations anyObject] coordinate];
    
    self.radius = [[[CLLocation alloc] initWithLatitude:minLat
                                              longitude:minLng]
                   distanceFromLocation:[[CLLocation alloc] initWithLatitude:maxLat
                                                                   longitude:maxLng]] / 2.f;
}



@end
