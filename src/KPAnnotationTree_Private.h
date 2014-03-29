//
//  KPAnnotationTree_Private.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "KPAnnotationTree.h"

#define KP_LIKELY(x) __builtin_expect(!!(x), 1)

static const size_t MKMapPointXOffset = offsetof(MKMapPoint, x);
static const size_t MKMapPointYOffset = offsetof(MKMapPoint, y);
static const size_t MKMapPointOffsets[] = { MKMapPointXOffset, MKMapPointYOffset };

static inline double MKMapPointGetCoordinateForAxis(MKMapPoint *point, int axis) {
    return *(double *)((char *)point + MKMapPointOffsets[axis]);
}


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


static inline kp_treenode_t * buildTree(kp_treenode_storage_t *nodeStorage, kp_internal_annotation_t *annotationsSortedByCurrentAxis, kp_internal_annotation_t *annotationsSortedByComplementaryAxis, kp_internal_annotation_t *temporaryAnnotationStorage, const NSUInteger count, const NSInteger curLevel);


@interface KPAnnotationTree ()

@property (nonatomic, readwrite) NSSet *annotations;

@property (nonatomic) kp_treenode_t *root;
@property (nonatomic) kp_treenode_storage_t *nodeStorage;

@end


