//
//  kp_2dtree.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 13/08/14.
//
//

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

typedef struct {
    kp_treenode_t *root;
    kp_treenode_t *nodes;
    kp_stack_t stack;
} kp_2dtree_t;

static inline kp_2dtree_t kp_2dtree_create(NSArray *annotations);
static inline void kp_2dtree_free(kp_2dtree_t *tree);
static inline void kp_2dtree_search(kp_treenode_t *curNode, MKMapPoint *minPoint, MKMapPoint *maxPoint, NSMutableArray *annotations, KPAnnotationTreeAxis axis);

static inline void kp_2dtree_search(kp_treenode_t *curNode, MKMapPoint *minPoint, MKMapPoint *maxPoint, NSMutableArray *annotations, KPAnnotationTreeAxis axis) {
    if (curNode == NULL) {
        return;
    }

    if (minPoint->x <= curNode->mapPoint.x &&
        minPoint->y <= curNode->mapPoint.y &&
        curNode->mapPoint.x <= maxPoint->x &&
        curNode->mapPoint.y <= maxPoint->y) {
        [annotations addObject:curNode->annotation];
    }

    double val = MKMapPointGetCoordinateForAxis(&curNode->mapPoint, axis);

    KPAnnotationTreeAxis complementaryAxis = axis ^ 1;

    if (MKMapPointGetCoordinateForAxis(maxPoint, axis) < val) {
        kp_2dtree_search(curNode->left, minPoint, maxPoint, annotations, complementaryAxis);
    }

    else if (MKMapPointGetCoordinateForAxis(minPoint, axis) >= val){
        kp_2dtree_search(curNode->right, minPoint, maxPoint, annotations, complementaryAxis);
    }

    else {
        kp_2dtree_search(curNode->left, minPoint, maxPoint, annotations, complementaryAxis);
        kp_2dtree_search(curNode->right, minPoint, maxPoint, annotations, complementaryAxis);
    }
}

#pragma mark - MKMapView

#pragma mark - Tree Building (Private)

static inline kp_2dtree_t kp_2dtree_create(NSArray *annotations) {
    kp_2dtree_t tree;

    NSUInteger count = annotations.count;

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

    kp_treenode_t *nodes = malloc(count * sizeof(kp_treenode_t));
    tree.nodes = nodes;

    __block
    kp_internal_annotation_t *annotationsX = malloc(count * sizeof(kp_internal_annotation_t));
    kp_internal_annotation_t *annotationsY = malloc(count * sizeof(kp_internal_annotation_t));

    MKMapPoint *KPTemporaryPointStorage = malloc(count * sizeof(MKMapPoint));
    kp_internal_annotation_t *KPTemporaryAnnotationStorage = malloc((count / 2) * sizeof(kp_internal_annotation_t));

    dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t idx) {
        id <MKAnnotation> annotation = annotations[idx];

        MKMapPoint mapPoint = MKMapPointForCoordinate(annotation.coordinate);

        KPTemporaryPointStorage[idx] = mapPoint;

        kp_internal_annotation_t _annotation;

        _annotation.annotation = annotation;
        _annotation.mapPoint = KPTemporaryPointStorage + idx;

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

    kp_treenode_t *nodeIterator = tree.nodes;
    tree.root = tree.nodes;

    kp_stack_info_t *stack_info = malloc(count * sizeof(kp_stack_info_t));
    kp_stack_info_t *stack_info_iterator = stack_info;

    kp_stack_t stack = kp_stack_create(count);
    kp_stack_push(&stack, NULL);

    kp_stack_info_t *top = stack_info_iterator++;
    top->level = 0;
    top->count = (uint32_t)count;
    top->node  = nodeIterator++;
    top->annotationsSortedByCurrentAxis       = annotationsX;
    top->annotationsSortedByComplementaryAxis = annotationsY;
    top->temporaryAnnotationStorage           = KPTemporaryAnnotationStorage;

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

        top->node->annotation = top->annotationsSortedByCurrentAxis[medianIdx].annotation;
        top->node->mapPoint = *(top->annotationsSortedByCurrentAxis[medianIdx].mapPoint);

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

        if (rightAnnotationsSortedByComplementaryAxisCount > 0) {
            stack_info_iterator->annotationsSortedByCurrentAxis       = top->annotationsSortedByComplementaryAxis + medianIdx + 1;
            stack_info_iterator->annotationsSortedByComplementaryAxis = top->annotationsSortedByCurrentAxis + (medianIdx + 1);;
            stack_info_iterator->temporaryAnnotationStorage           = top->temporaryAnnotationStorage;

            stack_info_iterator->count                                = (uint32_t)rightAnnotationsSortedByComplementaryAxisCount;
            stack_info_iterator->level                                = top->level + 1;

            stack_info_iterator->node = nodeIterator++;
            top->node->right = stack_info_iterator->node;

            kp_stack_push(&stack, stack_info_iterator++);
        } else {
            top->node->right = NULL;
        }

        if (leftAnnotationsSortedByComplementaryAxisCount > 0) {
            stack_info_iterator->annotationsSortedByCurrentAxis       = top->temporaryAnnotationStorage;;
            stack_info_iterator->annotationsSortedByComplementaryAxis = top->annotationsSortedByCurrentAxis;
            stack_info_iterator->temporaryAnnotationStorage           = top->annotationsSortedByComplementaryAxis;

            stack_info_iterator->count                                = (uint32_t)leftAnnotationsSortedByComplementaryAxisCount;
            stack_info_iterator->level                                = top->level + 1;

            stack_info_iterator->node = nodeIterator++;
            top->node->left = stack_info_iterator->node;
            
            kp_stack_push(&stack, stack_info_iterator++);
        } else {
            top->node->left = NULL;
        }
        
        top = kp_stack_pop(&stack);
    }
    
    tree.stack = stack;
    
    free(stack_info);
    free(annotationsX);
    free(annotationsY);
    
    free(KPTemporaryAnnotationStorage);
    free(KPTemporaryPointStorage);
    
    return tree;
}

static inline void kp_2dtree_free(kp_2dtree_t *tree) {
    free(tree->nodes);
    free(tree->stack.storage);
}
