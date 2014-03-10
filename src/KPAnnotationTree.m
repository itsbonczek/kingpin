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

#import "KPTreeNode.h"

#import "KPAnnotation.h"

#import <assert.h>
#import <stddef.h>

#if 0
#define BBTreeLog(...) NSLog(__VA_ARGS__)
#else
#define BBTreeLog(...) ((void) 0)
#endif

#define KP_LIKELY(x) __builtin_expect(!!(x), 1)

typedef struct {
    __unsafe_unretained id <MKAnnotation> annotation;

    MKMapPoint *mapPoint;
} kp_internal_annotation_t;

typedef enum {
    KPAnnotationTreeAxisX = 0,
    KPAnnotationTreeAxisY = 1,
} KPAnnotationTreeAxis;


static const size_t MKMapPointXOffset = offsetof(MKMapPoint, x);
static const size_t MKMapPointYOffset = offsetof(MKMapPoint, y);
static const size_t MKMapPointOffsets[] = { MKMapPointXOffset, MKMapPointYOffset };

static inline double MKMapPointGetCoordinateForAxis(MKMapPoint *point, int axis) {
    return *(double *)((char *)point + MKMapPointOffsets[axis]);
}

static inline KPTreeNode * buildTree(kp_internal_annotation_t *annotationsSortedByCurrentAxis, kp_internal_annotation_t *annotationsSortedByComplementaryAxis, const NSUInteger count, const NSInteger curLevel);

static kp_internal_annotation_t *KPTemporaryAnnotationStorage;
static MKMapPoint *KPTemporaryPointStorage;

@implementation KPAnnotationTree

- (id)initWithAnnotations:(NSArray *)annotations {
    
    self = [super init];
    
    if(self){
        self.annotations = [NSSet setWithArray:annotations];
        [self buildTree:annotations];
    }
    
    return self;
}

#pragma mark - Search

- (NSArray *)annotationsInMapRect:(MKMapRect)rect {
    
    NSMutableArray *result = [NSMutableArray array];
    
    [self doSearchInMapRect:rect
         mutableAnnotations:result
                    curNode:self.root
                   curLevel:0];
    
    return result;
}


- (void)doSearchInMapRect:(MKMapRect)mapRect 
       mutableAnnotations:(NSMutableArray *)annotations 
                  curNode:(KPTreeNode *)curNode
                 curLevel:(NSInteger)level {
    
    if(curNode == nil){
        return;
    }
    
    MKMapPoint mapPoint = curNode.mapPoint;
   
    BBTreeLog(@"Testing (%f, %f)...", [curNode.annotation coordinate].latitude, [curNode.annotation coordinate].longitude);
    
    if(MKMapRectContainsPoint(mapRect, mapPoint)){
        BBTreeLog(@"YES");
        [annotations addObject:curNode.annotation];
    }
    else {
        BBTreeLog(@"RECT: NO");
    }

    KPAnnotationTreeAxis axis = (level & 1) == 0 ? KPAnnotationTreeAxisX : KPAnnotationTreeAxisY;

    double val, minVal, maxVal;

    if (axis == KPAnnotationTreeAxisX) {
        val    = mapPoint.x;
        minVal = mapRect.origin.x;
        maxVal = mapRect.origin.x + mapRect.size.width;
    } else {
        val    = mapPoint.y;
        minVal = mapRect.origin.y;
        maxVal = mapRect.origin.y + mapRect.size.height;
    }

    if(maxVal < val){
        
        [self doSearchInMapRect:mapRect
             mutableAnnotations:annotations
                        curNode:curNode.left
                       curLevel:(level + 1)];
    }
    else if(minVal >= val){
        
        [self doSearchInMapRect:mapRect
             mutableAnnotations:annotations
                        curNode:curNode.right
                       curLevel:(level + 1)];
    }
    else {
        
        [self doSearchInMapRect:mapRect
             mutableAnnotations:annotations
                        curNode:curNode.left
                       curLevel:(level + 1)];
        
        [self doSearchInMapRect:mapRect
             mutableAnnotations:annotations
                        curNode:curNode.right
                       curLevel:(level + 1)];
    }
    
}

#pragma mark - MKMapView


#pragma mark - Tree Building (Private)


- (void)buildTree:(NSArray *)annotations {
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

    __block
    kp_internal_annotation_t *annotationsX = malloc(count * sizeof(kp_internal_annotation_t));
    kp_internal_annotation_t *annotationsY = malloc(count * sizeof(kp_internal_annotation_t));

    KPTemporaryPointStorage = malloc(count * sizeof(MKMapPoint));

    [annotations enumerateObjectsUsingBlock:^(id <MKAnnotation> annotation, NSUInteger idx, BOOL *stop) {
        MKMapPoint mapPoint = MKMapPointForCoordinate(annotation.coordinate);

        kp_internal_annotation_t _annotation;
        _annotation.annotation = annotation;

        KPTemporaryPointStorage[idx] = mapPoint;

        _annotation.mapPoint = KPTemporaryPointStorage + idx;

        annotationsX[idx] = _annotation;
    }];

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

    KPTemporaryAnnotationStorage = malloc(count * sizeof(kp_internal_annotation_t));

    self.root = buildTree(annotationsX, annotationsY, count, 0);

    free(annotationsX);
    free(annotationsY);
    
    free(KPTemporaryAnnotationStorage);
    free(KPTemporaryPointStorage);
}

@end


static inline KPTreeNode * buildTree(kp_internal_annotation_t *annotationsSortedByCurrentAxis, kp_internal_annotation_t *annotationsSortedByComplementaryAxis, const NSUInteger count, const NSInteger curLevel) {
    if (count == 0) {
        return nil;
    }

    KPTreeNode *n = [[KPTreeNode alloc] init];


    // We prefer machine way of doing odd/even check over the mathematical one: "% 2"
    KPAnnotationTreeAxis axis = (curLevel & 1) == 0 ? KPAnnotationTreeAxisX : KPAnnotationTreeAxisY;


    NSUInteger medianIdx = count / 2;

    kp_internal_annotation_t medianAnnotation = annotationsSortedByCurrentAxis[medianIdx];


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

    while (medianIdx > 0 && MKMapPointGetCoordinateForAxis(annotationsSortedByCurrentAxis[medianIdx - 1].mapPoint, axis) == MKMapPointGetCoordinateForAxis(annotationsSortedByCurrentAxis[medianIdx].mapPoint, axis)) {
        medianIdx--;
    }

    n.annotation = annotationsSortedByCurrentAxis[medianIdx].annotation;
    n.mapPoint = *(annotationsSortedByCurrentAxis[medianIdx].mapPoint);


    kp_internal_annotation_t *leftAnnotationsSortedByComplementraryAxis  = KPTemporaryAnnotationStorage;
    kp_internal_annotation_t *rightAnnotationsSortedByComplementraryAxis = KPTemporaryAnnotationStorage + medianIdx;


    NSUInteger leftAnnotationsSortedByComplementaryAxisCount = 0;
    NSUInteger rightAnnotationsSortedByComplementaryAxisCount = 0;
    
    for (NSUInteger i = 0; i < count; i++) {
        kp_internal_annotation_t annotation = annotationsSortedByComplementaryAxis[i];

        /*
         KP_LIKELY macros, based on __builtin_expect, is used for branch prediction. The performance gain from this is expected to be very small, but it is still logically good to predict branches which are likely to occur often and often.
         
         We check median annotation to skip it because it is already added to the current node.
         */
        if (KP_LIKELY([annotation.annotation isEqual:n.annotation] == NO)) {
            if (MKMapPointGetCoordinateForAxis(annotation.mapPoint, axis) < splittingCoordinate) {
                leftAnnotationsSortedByComplementraryAxis[leftAnnotationsSortedByComplementaryAxisCount++] = annotation;
            } else {
                rightAnnotationsSortedByComplementraryAxis[rightAnnotationsSortedByComplementaryAxisCount++] = annotation;
            }
        }
    }


    // Ensure integrity (development assert, maybe removed in production)
    #ifdef DEBUG
    assert(leftAnnotationsSortedByComplementaryAxisCount == medianIdx);
    assert(rightAnnotationsSortedByComplementaryAxisCount == (count - medianIdx - 1));
    #endif


    memcpy(annotationsSortedByComplementaryAxis, leftAnnotationsSortedByComplementraryAxis, leftAnnotationsSortedByComplementaryAxisCount * sizeof(kp_internal_annotation_t));
    memcpy(annotationsSortedByComplementaryAxis + leftAnnotationsSortedByComplementaryAxisCount, rightAnnotationsSortedByComplementraryAxis, rightAnnotationsSortedByComplementaryAxisCount * sizeof(kp_internal_annotation_t));


    /*
     The following strings use C pointer <s>gymnastics</s> arithmetics a[i] = *(a + i):

     (a + i) gives us pointer (not value!) to ith element so we can pass this pointer downstream, to the buildTree() of next level of depth.

     This allows reduce a number of allocations of temporary X and Y arrays by a factor of 2:
     On each level of depth we derive only one couple of arrays, the second couple is passed as is just using this C pointer arithmetic.
     */

    leftAnnotationsSortedByComplementraryAxis  = annotationsSortedByComplementaryAxis;
    rightAnnotationsSortedByComplementraryAxis = annotationsSortedByComplementaryAxis + leftAnnotationsSortedByComplementaryAxisCount;

    kp_internal_annotation_t *leftAnnotationsSortedByCurrentAxis  = annotationsSortedByCurrentAxis;
    kp_internal_annotation_t *rightAnnotationsSortedByCurrentAxis = annotationsSortedByCurrentAxis + (medianIdx + 1);


    n.left  = buildTree(leftAnnotationsSortedByComplementraryAxis, leftAnnotationsSortedByCurrentAxis, leftAnnotationsSortedByComplementaryAxisCount, curLevel + 1);
    n.right = buildTree(rightAnnotationsSortedByComplementraryAxis, rightAnnotationsSortedByCurrentAxis, rightAnnotationsSortedByComplementaryAxisCount, curLevel + 1);


    return n;
}
