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
        self.annotations = [NSSet setWithArray:annotations];
        self.tree = kp_2dtree_create(annotations);
    }

    return self;
}

- (void)dealloc {
    kp_2dtree_free(& _tree);

    _annotations = nil;
}

#pragma mark - Search

- (NSArray *)annotationsInMapRect:(MKMapRect)rect {
    NSMutableArray *result = [NSMutableArray array];

    MKMapPoint minPoint = rect.origin;
    MKMapPoint maxPoint = MKMapPointMake(MKMapRectGetMaxX(rect), MKMapRectGetMaxY(rect));

    kp_2dtree_t tree = self.tree;
    kp_2dtree_search(tree.root, &minPoint, &maxPoint, result, KPAnnotationTreeAxisX);

    return result;
}

@end
