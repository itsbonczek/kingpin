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
    return [NSString stringWithFormat:@"Single Annotation"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; coordinate = (%f, %f)>", NSStringFromClass(self.class), self, self.coordinate.latitude, self.coordinate.longitude];
}

@end
