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

#import "KPAnnotationTree.h"
#import "KPAnnotationTree_Private.h"

#import "KPAnnotation.h"

#import "KPGeometry.h"

@implementation KPAnnotationTree

- (id)initWithAnnotations:(NSArray *)annotations {
    
    self = [super init];
    
    if (self) {
        _annotations = [NSSet setWithArray:annotations];

        // The following ifndef is to prevent Analyzer from producing incorrect warning:
        // "Function call argument is an uninitialized value (within a call to)"
        // see https://github.com/itsbonczek/kingpin/issues/69

#ifndef __clang_analyzer__
        _tree = kp_2dtree_create(annotations);
#endif
    }

    return self;
}

- (void)dealloc {
    kp_2dtree_free(& _tree);

    _annotations = nil;
}

#pragma mark - Search

- (NSArray *)annotationsInMapRect:(MKMapRect)rect {
    MKMapRect normalizedRect = rect;

    double rectMinX = fmod(MKMapRectGetMinX(rect), MKMapRectWorld.size.width);
    double rectMaxX = fmod(MKMapRectGetMaxX(rect), MKMapRectWorld.size.width);

    if (rectMinX > rectMaxX) {
        MKMapRect rectLeft = MKMapRectMake(
                                           rectMinX,
                                           rect.origin.y,
                                           MKMapRectWorld.size.width - rectMinX,
                                           rect.size.height
                                           );

        NSArray *annotationsLeft = [self _annotationsInMapRect:rectLeft];

        MKMapRect rectRight = MKMapRectMake(
                                            0,
                                            rect.origin.y,
                                            rectMaxX,
                                            rect.size.height
                                            );

        NSArray *annotationsRight = [self _annotationsInMapRect:rectRight];

        NSMutableArray *annotationsLeftMinusRight = [annotationsLeft mutableCopy];
        [annotationsLeftMinusRight removeObjectsInArray:annotationsRight];

        NSAssert([annotationsLeftMinusRight isEqualToArray:annotationsLeft], nil);

        return [annotationsLeft arrayByAddingObjectsFromArray:annotationsRight];
    } else {
        normalizedRect.origin.x = rectMinX;

        NSArray *annotations = [self _annotationsInMapRect:normalizedRect];
        
        return annotations;
    }
}

#pragma mark - Private

- (NSArray *)_annotationsInMapRect:(MKMapRect)rect {
    NSMutableArray *result = [NSMutableArray array];

    MKMapPoint minPoint = rect.origin;
    MKMapPoint maxPoint = MKMapPointMake(MKMapRectGetMaxX(rect), MKMapRectGetMaxY(rect));

    kp_2dtree_t tree = self.tree;
    kp_2dtree_search(&tree, result, &minPoint, &maxPoint);

    return result;
}

@end
