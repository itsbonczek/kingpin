//
//  TestAnnotation.m
//  BBAnnotationTree2
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TestAnnotation.h"

@implementation TestAnnotation

- (NSString *)title {
    return [NSString stringWithFormat:@"%li", (long)self.level];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: (%f, %f)", [super description], self.coordinate.latitude, self.coordinate.longitude];
}

@end
