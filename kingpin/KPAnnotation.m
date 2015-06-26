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

#import "KPGeometry.h"

@interface KPAnnotation ()

@property (strong, readwrite, nonatomic) NSSet *annotations;
@property (assign, readwrite, nonatomic) CLLocationDistance radius;

@end

@implementation KPAnnotation

- (id)initWithAnnotations:(NSArray *)annotations {
    return [self initWithAnnotationSet:[NSSet setWithArray:annotations]];
}

- (id)initWithAnnotationSet:(NSSet *)set {
    self = [super init];
    
    if (self == nil) {
        return nil;
    }

    self.annotations = set;
    self.title = [NSString stringWithFormat:@"%lu things", (unsigned long)[self.annotations count]];;
    [self calculateValues];
    
    return self;
}

- (BOOL)isCluster {
    return (self.annotations.count > 1);
}

#pragma mark - Private

- (void)calculateValues {
    NSUInteger count = self.annotations.count;

    if (count == 0) {
        return;
    }

    if (count == 1) {
        self.radius = 0;
        self.coordinate = [[[self annotations] anyObject] coordinate];

        return;
    }

    CLLocationDegrees minLat = NSIntegerMax;
    CLLocationDegrees minLng = NSIntegerMax;
    CLLocationDegrees maxLat = NSIntegerMin;
    CLLocationDegrees maxLng = NSIntegerMin;

    CLLocationDegrees totalLat = 0;
    CLLocationDegrees totalLng = 0;

    NSUInteger idx = 0;
    CLLocationCoordinate2D coords[2];

    /* 
     This algorithm is approx. 1.2-2x faster than naive one.
     It is described here: https://github.com/EvgenyKarkan/EKAlgorithms/issues/30
     */
    for (id <MKAnnotation> ithAnnotation in self.annotations) {
        // Machine way of doing odd/even check is better than mathematical count % 2
        if (((idx++) & 1) == 0) {
            coords[0] = ithAnnotation.coordinate;

            continue;
        } else {
            coords[1] = ithAnnotation.coordinate;
        }

        CLLocationDegrees ithLatitude      = coords[0].latitude;
        CLLocationDegrees iplus1thLatitude = coords[1].latitude;

        CLLocationDegrees ithLongitude      = coords[0].longitude;
        CLLocationDegrees iplus1thLongitude = coords[1].longitude;

        if (ithLatitude < iplus1thLatitude) {
            minLat = MIN(minLat, ithLatitude);
            maxLat = MAX(maxLat, iplus1thLatitude);
        }
        else if (ithLatitude > iplus1thLatitude) {
            minLat = MIN(minLat, iplus1thLatitude);
            maxLat = MAX(maxLat, ithLatitude);
        }
        else {
            minLat = MIN(minLat, ithLatitude);
            maxLat = MAX(maxLat, ithLatitude);
        }

        if (ithLongitude < iplus1thLongitude) {
            minLng = MIN(minLng, ithLongitude);
            maxLng = MAX(maxLng, iplus1thLongitude);
        }
        else if (ithLongitude > iplus1thLongitude) {
            minLng = MIN(minLng, iplus1thLongitude);
            maxLng = MAX(maxLng, ithLongitude);
        }
        else {
            minLng = MIN(minLng, ithLongitude);
            maxLng = MAX(maxLng, ithLongitude);
        }

        totalLat += (ithLatitude + iplus1thLatitude);
        totalLng += (ithLongitude + iplus1thLongitude);
    }

    // If self.annotations has odd number elements we have unpaired last annotation coordinate values in coords[0]
    BOOL isOdd = count & 1;

    if (isOdd == 1) {
        CLLocationDegrees lastElementLatitude  = coords[0].latitude;
        CLLocationDegrees lastElementLongitude = coords[1].longitude;

        minLat = MIN(minLat, lastElementLatitude);
        minLng = MIN(minLng, lastElementLongitude);
        maxLat = MAX(maxLat, lastElementLatitude);
        maxLng = MAX(maxLng, lastElementLongitude);

        totalLat += lastElementLatitude;
        totalLng += lastElementLongitude;
    }

    self.coordinate = CLLocationCoordinate2DMake(totalLat / self.annotations.count,
                                                 totalLng / self.annotations.count);

    CLLocationDistance midPointToMax = MKMetersBetweenMapPoints(MKMapPointForCoordinate(self.coordinate),
                                                                MKMapPointForCoordinate(CLLocationCoordinate2DMake(maxLat, maxLng)));
    
    CLLocationDistance midPointToMin = MKMetersBetweenMapPoints(MKMapPointForCoordinate(self.coordinate),
                                                                MKMapPointForCoordinate(CLLocationCoordinate2DMake(minLat, minLng)));
    
    self.radius = MAX(midPointToMax, midPointToMin);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; coordinate = (%f, %f); annotations = %@>", NSStringFromClass(self.class), self, self.coordinate.latitude, self.coordinate.longitude, self.annotations];
}

@end
