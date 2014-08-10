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
    NSUInteger level;
} kp_treenode_t;

typedef struct {
    kp_internal_annotation_t *annotationsSortedByCurrentAxis;
    kp_internal_annotation_t *annotationsSortedByComplementaryAxis;
    kp_internal_annotation_t *temporaryAnnotationStorage;
    uint32_t count;
    uint32_t level;
    kp_treenode_t *node;
} kp_stack_info_t;

typedef struct {
    void **storage;
    void **top;
} kp_stack_t;

static inline kp_stack_t kp_stack_create(size_t capacity) {
    kp_stack_t stack;

    stack.storage = malloc(capacity * sizeof(void *));
    stack.top = stack.storage;

    return stack;
}

static inline void kp_stack_push(kp_stack_t *stack, void *el) {
    *(stack->top++) = el;
}

static inline void *kp_stack_pop(kp_stack_t *stack) {
    return *(--stack->top);
}

@interface KPAnnotationTree ()

@property (strong, nonatomic, readwrite) NSSet *annotations;

@property (assign, nonatomic) kp_treenode_t *root;
@property (assign, nonatomic) kp_treenode_t *nodes;

@end
