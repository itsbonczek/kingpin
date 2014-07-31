//
//  MockMapView.m
//  kingpin
//
//  Created by Bryan Bonczek on 6/1/14.
//
//

#import "MockMapView.h"

@implementation MockMapView

- (CGRect)frame {
    return CGRectMake(0, 0, 320, 480);
}

- (MKMapRect)visibleMapRect {
    return self.mockVisibleMapRect;
}

@end
