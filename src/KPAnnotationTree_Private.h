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

#import "KPGeometry.h"

#define KP_LIKELY(x) __builtin_expect(!!(x), 1)

typedef struct {
    __unsafe_unretained id <MKAnnotation> annotation;

    MKMapPoint *mapPoint;
} kp_internal_annotation_t;

typedef enum {
    KPAnnotationTreeAxisX = 0,
    KPAnnotationTreeAxisY = 1,
} KPAnnotationTreeAxis;

typedef struct kp_treenode_t {
    __unsafe_unretained id<MKAnnotation> annotation;
    struct kp_treenode_t *left;
    struct kp_treenode_t *right;
    MKMapPoint mapPoint;
} kp_treenode_t;

typedef struct {
    kp_treenode_t *nodes;
    NSUInteger freeIdx;
} kp_treenode_storage_t;

static inline kp_treenode_t * kp_tree_build(kp_treenode_storage_t *nodeStorage, kp_internal_annotation_t *annotationsSortedByCurrentAxis, kp_internal_annotation_t *annotationsSortedByComplementaryAxis, kp_internal_annotation_t *temporaryAnnotationStorage, const NSUInteger count, const NSInteger curLevel);

@interface KPAnnotationTree ()

@property (strong, nonatomic, readwrite) NSSet *annotations;

@property (assign, nonatomic) kp_treenode_t *root;
@property (assign, nonatomic) kp_treenode_storage_t *nodeStorage;

@end
