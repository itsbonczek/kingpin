//
//  KPConfiguration.m
//  kingpin
//
//  Created by Stanislaw Pankevich on 21/04/14.
//
//

#import "KPConfiguration.h"

@implementation KPConfiguration

- (id)init {
    self = [super init];

    if (self == nil) return nil;

    self.gridSize = (CGSize){60.f, 60.f};
    self.annotationSize = (CGSize){60.f, 60.f};
    self.annotationCenterOffset = (CGPoint){30.f, 30.f};
    self.animationDuration = 0.5f;
    self.clusteringEnabled = YES;

    return self;
}

@end
