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

#import "KPGeometry.h"

#import <MapKit/MKAnnotation.h>

#define KP_LIKELY(x) __builtin_expect(!!(x), 1)

typedef struct {
    __unsafe_unretained id <MKAnnotation> annotation;

    MKMapPoint *mapPoint;
} kp_internal_annotation_t;

// don't use NSInteger to avoid padding in some structs
typedef NS_ENUM(int, KPAnnotationTreeAxis) {
    KPAnnotationTreeAxisX = 0,
    KPAnnotationTreeAxisY = 1,
};

typedef struct kp_treenode_t {
    __unsafe_unretained id <MKAnnotation> annotation;
    struct kp_treenode_t *left;
    struct kp_treenode_t *right;
    MKMapPoint mk_map_point;
    NSUInteger level;
} kp_treenode_t;

typedef struct {
    kp_internal_annotation_t *annotationsSortedByCurrentAxis;
    kp_internal_annotation_t *annotationsSortedByComplementaryAxis;
    kp_internal_annotation_t *temporaryAnnotationStorage;
    uint32_t count;
    uint32_t level;
    kp_treenode_t *node;
} kp_build_stack_info_t;

typedef struct {
    uint32_t level;
    KPAnnotationTreeAxis axis;
    kp_treenode_t *node;
} kp_search_stack_info_t;

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

static inline void kp_stack_reset(kp_stack_t *stack) {
    stack->top = stack->storage;
}

typedef struct {
    kp_treenode_t *root;
    kp_stack_t stack;
    NSUInteger size;
    kp_search_stack_info_t *search_stack_info;
} kp_2dtree_t;

static inline kp_2dtree_t kp_2dtree_create(NSArray *annotations);
static inline void kp_2dtree_free(kp_2dtree_t *tree);
static inline void kp_2dtree_search(kp_2dtree_t *tree, NSMutableArray *result, MKMapPoint *minPoint, MKMapPoint *maxPoint);

#pragma mark -

static inline void kp_2dtree_free(kp_2dtree_t *tree) {
    if (tree->size == 0) return;

    free(tree->root);
    free(tree->stack.storage);
    free(tree->search_stack_info);
}

static inline kp_2dtree_t kp_2dtree_create(NSArray *annotations) {
    kp_2dtree_t tree;
    memset(&tree, 0, sizeof(kp_2dtree_t));

    NSUInteger count = annotations.count;

    if (count == 0) return tree;

    tree.size = count;

    tree.search_stack_info = malloc(count * sizeof(kp_search_stack_info_t));
    tree.root = malloc(count * sizeof(kp_treenode_t));

    kp_build_stack_info_t *build_stack_info = malloc(count * sizeof(kp_build_stack_info_t));
    kp_build_stack_info_t *top_snapshot;

    kp_stack_t stack = kp_stack_create(count);
    tree.stack = stack;

    kp_internal_annotation_t *annotationsX = malloc(count * sizeof(kp_internal_annotation_t));
    kp_internal_annotation_t *annotationsY = malloc(count * sizeof(kp_internal_annotation_t));

    MKMapPoint *temporary_point_storage = malloc(count * sizeof(MKMapPoint));
    kp_internal_annotation_t *temporary_annotation_storage = malloc((count / 2) * sizeof(kp_internal_annotation_t));

    /*
     Kingpin currently implements the algorithm similar to the what is described as "A novel tree-building algorithm" on Wikipedia page:
     (follow these lines on http://en.wikipedia.org/wiki/K-d_tree).

     1. Sorting of original array by x and y is now done only once before building a tree.

     2. MKMapPointForCoordinate is now calculated only once for each annotation right before building of a tree.

     C level struct kp_internal_annotation is introduced to make 1 and 2 possible:
     - These structs serve as containers for both id <MKAnnotation> annotations and their once-precalculated MKMapPoints.
     - These structs and arrays of them allow to eliminate NSObject-based allocations (NSArray and NSIndexSet)
     - These structs allow to skip allocations of corresponding containers on every level of depth.
     */

    dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t idx) {
        id <MKAnnotation> annotation = annotations[idx];

        MKMapPoint mapPoint = MKMapPointForCoordinate(annotation.coordinate);

        temporary_point_storage[idx] = mapPoint;

        kp_internal_annotation_t _annotation;

        _annotation.annotation = annotation;
        _annotation.mapPoint = temporary_point_storage + idx;

        annotationsX[idx] = _annotation;
    });

    qsort_b(annotationsX, count, sizeof(kp_internal_annotation_t), ^int(const void *a1, const void *a2) {
        kp_internal_annotation_t *annotation1 = (kp_internal_annotation_t *)a1;
        kp_internal_annotation_t *annotation2 = (kp_internal_annotation_t *)a2;

        if (annotation1->mapPoint->x > annotation2->mapPoint->x) {
            return NSOrderedDescending;
        }

        if (annotation1->mapPoint->x < annotation2->mapPoint->x) {
            return NSOrderedAscending;
        }

        return NSOrderedSame;
    });

    memcpy(annotationsY, annotationsX, count * sizeof(kp_internal_annotation_t));

    qsort_b(annotationsY, count, sizeof(kp_internal_annotation_t), ^int(const void *a1, const void *a2) {
        kp_internal_annotation_t *annotation1 = (kp_internal_annotation_t *)a1;
        kp_internal_annotation_t *annotation2 = (kp_internal_annotation_t *)a2;

        if (annotation1->mapPoint->y > annotation2->mapPoint->y) {
            return NSOrderedDescending;
        }

        if (annotation1->mapPoint->y < annotation2->mapPoint->y) {
            return NSOrderedAscending;
        }

        return NSOrderedSame;
    });

    kp_stack_push(&stack, NULL);

    kp_treenode_t *free_node_iterator = tree.root;

    kp_build_stack_info_t *top = build_stack_info;
    top->level = 0;
    top->count = (uint32_t)count;
    top->node  = free_node_iterator++;
    top->annotationsSortedByCurrentAxis       = annotationsX;
    top->annotationsSortedByComplementaryAxis = annotationsY;
    top->temporaryAnnotationStorage           = temporary_annotation_storage;

    while (top != NULL) {
        // We prefer machine way of doing odd/even check over the mathematical one: "% 2"
        KPAnnotationTreeAxis axis = (top->level & 1) == 0 ? KPAnnotationTreeAxisX : KPAnnotationTreeAxisY;

        NSUInteger medianIdx = top->count >> 1;

        kp_internal_annotation_t medianAnnotation = top->annotationsSortedByCurrentAxis[medianIdx];

        double splittingCoordinate = MKMapPointGetCoordinateForAxis(medianAnnotation.mapPoint, axis);

        /*
         http://en.wikipedia.org/wiki/K-d_tree#Construction

         Arrays should be split into subarrays that represent "less than" and "greater than or equal to" partitioning.
         This convention requires that, after choosing the median element of array 0, the element of array 0 that lies immediately below the median element be
         examined to ensure that this adjacent element references a point whose x-coordinate is less than and not equal to the x-coordinate of the splitting plane.
         If this adjacent element references a point whose x-coordinate is equal to the x-coordinate of the splitting plane, continue searching towards the beginning
         of array 0 until the first instance of an array element is found that references a point whose x-coordinate is less than and not equal to the x-coordinate
         of the splitting plane. When this array element is found, the element that lies immediately above this element is the correct choice for the median element.
         Apply this method of choosing the median element at each level of recursion.
         */

        while (medianIdx > 0 && MKMapPointGetCoordinateForAxis(top->annotationsSortedByCurrentAxis[medianIdx - 1].mapPoint, axis) == MKMapPointGetCoordinateForAxis(top->annotationsSortedByCurrentAxis[medianIdx].mapPoint, axis)) {
            medianIdx--;
        }

        top->node->annotation   = top->annotationsSortedByCurrentAxis[medianIdx].annotation;
        top->node->mk_map_point = *(top->annotationsSortedByCurrentAxis[medianIdx].mapPoint);

        /*
         The following strings take heavy use of C pointer <s>gymnastics</s> arithmetics:

         a[i] = *(a + i)

         (a + i) gives us pointer (not value!) to ith element so we can pass this pointer downstream, to the buildTree() of next level of depth.

         This allows reduce a number of allocations of temporary X and Y arrays by a factor of 2:
         On each level of depth we derive only one couple of arrays, the second couple is passed as is just using this C pointer arithmetic.

         We accumulate "left" annotations  (i.e. whose coordinates are  < than splitting coordinate) in current temporary storage.
         We accumulate "right" annotations (i.e. whose coordinates are >= than splitting coordinate) in right portion of annotationsSortedByComplementaryAxis.
         Unused left portion of annotationsSortedByComplementaryAxis is reused as 'new' temporary storage when passed downstream when building left leaves
         */

        kp_internal_annotation_t *leftAnnotationsSortedByComplementaryAxisBackwardIterator  = top->temporaryAnnotationStorage + (medianIdx - 1);
        kp_internal_annotation_t *rightAnnotationsSortedByComplementaryAxisBackwardIterator = top->annotationsSortedByComplementaryAxis + (top->count - 1);

        kp_internal_annotation_t *annotationsSortedByComplementaryAxisBackwardIterator = top->annotationsSortedByComplementaryAxis + (top->count - 1);

        NSUInteger idx = top->count;

        do {
            idx--;

            /*
             KP_LIKELY macros, based on __builtin_expect, is used for branch prediction. The performance gain from this is expected to be very small, but it is still logically good to predict branches which are likely to occur often and often.

             We check median annotation to skip it because it is already added to the current node.
             */
            if (KP_LIKELY([annotationsSortedByComplementaryAxisBackwardIterator->annotation isEqual:top->node->annotation] == NO)) {
                if (MKMapPointGetCoordinateForAxis(annotationsSortedByComplementaryAxisBackwardIterator->mapPoint, axis) < splittingCoordinate) {
                    *(leftAnnotationsSortedByComplementaryAxisBackwardIterator--)  = *annotationsSortedByComplementaryAxisBackwardIterator;
                } else {
                    *(rightAnnotationsSortedByComplementaryAxisBackwardIterator--) = *annotationsSortedByComplementaryAxisBackwardIterator;
                }
            }

            annotationsSortedByComplementaryAxisBackwardIterator--;
        } while (idx != 0);

        NSUInteger leftAnnotationsSortedByComplementaryAxisCount  = medianIdx;
        NSUInteger rightAnnotationsSortedByComplementaryAxisCount = top->count - medianIdx - 1;

        top_snapshot = top;

        if (rightAnnotationsSortedByComplementaryAxisCount > 0) {
            top++;

            top->annotationsSortedByCurrentAxis       = top_snapshot->annotationsSortedByComplementaryAxis + medianIdx + 1;
            top->annotationsSortedByComplementaryAxis = top_snapshot->annotationsSortedByCurrentAxis + (medianIdx + 1);;
            top->temporaryAnnotationStorage           = top_snapshot->temporaryAnnotationStorage;

            top->count                                = (uint32_t)rightAnnotationsSortedByComplementaryAxisCount;
            top->level                                = top_snapshot->level + 1;

            top->node = free_node_iterator++;

            top_snapshot->node->right = top->node;

            kp_stack_push(&stack, top);
        } else {
            top_snapshot->node->right = NULL;
        }

        if (leftAnnotationsSortedByComplementaryAxisCount > 0) {
            top++;

            top->annotationsSortedByCurrentAxis       = top_snapshot->temporaryAnnotationStorage;;
            top->annotationsSortedByComplementaryAxis = top_snapshot->annotationsSortedByCurrentAxis;
            top->temporaryAnnotationStorage           = top_snapshot->annotationsSortedByComplementaryAxis;

            top->count                                = (uint32_t)leftAnnotationsSortedByComplementaryAxisCount;
            top->level                                = top_snapshot->level + 1;

            top->node = free_node_iterator++;
            top_snapshot->node->left = top->node;
            
            kp_stack_push(&stack, top);
        } else {
            top_snapshot->node->left = NULL;
        }
        
        top = kp_stack_pop(&stack);
    }

    free(build_stack_info);
    free(annotationsX);
    free(annotationsY);
    
    free(temporary_annotation_storage);
    free(temporary_point_storage);
    
    return tree;
}

static inline void kp_2dtree_search(kp_2dtree_t *tree, NSMutableArray *result, MKMapPoint *minPoint, MKMapPoint *maxPoint) {
    if (tree->size == 0) return;

    kp_stack_reset(&tree->stack);
    kp_stack_push(&tree->stack, NULL);

    kp_search_stack_info_t *top = tree->search_stack_info;
    kp_search_stack_info_t *top_snapshot;

    top->level = 0;
    top->node = tree->root;
    top->axis = 0;

    while (top != NULL) {
        if (minPoint->x <= top->node->mk_map_point.x &&
            minPoint->y <= top->node->mk_map_point.y &&
            top->node->mk_map_point.x <= maxPoint->x &&
            top->node->mk_map_point.y <= maxPoint->y) {
            [result addObject:top->node->annotation];
        }

        double val = MKMapPointGetCoordinateForAxis(&top->node->mk_map_point, top->axis);

        KPAnnotationTreeAxis complementaryAxis = top->axis ^ 1;

        top_snapshot = top;

        if (MKMapPointGetCoordinateForAxis(maxPoint, top->axis) < val && top_snapshot->node->left != NULL) {
            top++;

            top->axis  = complementaryAxis;
            top->level = top_snapshot->level + 1;
            top->node  = top_snapshot->node->left;

            kp_stack_push(&tree->stack, top);
        }

        else if (MKMapPointGetCoordinateForAxis(minPoint, top->axis) >= val && top_snapshot->node->right != NULL){
            top++;

            top->axis  = complementaryAxis;
            top->level = top_snapshot->level + 1;
            top->node  = top_snapshot->node->right;

            kp_stack_push(&tree->stack, top);
        }

        else {
            if (top_snapshot->node->right != NULL) {
                top++;

                top->axis  = complementaryAxis;
                top->level = top_snapshot->level + 1;
                top->node  = top_snapshot->node->right;

                kp_stack_push(&tree->stack, top);
            }

            if (top_snapshot->node->left != NULL) {
                top++;

                top->axis  = complementaryAxis;
                top->level = top_snapshot->level + 1;
                top->node  = top_snapshot->node->left;

                kp_stack_push(&tree->stack, top);
            }
        }

        top = kp_stack_pop(&tree->stack);
    }
}

