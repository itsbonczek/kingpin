//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "TestHelpers.h"

#import "KPAnnotationTree.h"
#import "KPAnnotationTree_Private.h"

#import "TestAnnotation.h"

#import "Datasets.h"

@interface KPAnnotationTreeTests : XCTestCase
@end

typedef struct {
    kp_treenode_t *node;
    int level;
} kp_stack_el_t;


@implementation KPAnnotationTreeTests

- (void)testStack {
    kp_stack_t stack = kp_stack_create(10);
    int a = 1;
    int b = 2;
    int c = 3;

    kp_stack_push(&stack, &a);
    kp_stack_push(&stack, &b);
    kp_stack_push(&stack, &c);

    int *exp_c = kp_stack_pop(&stack);
    XCTAssert(*exp_c == c);

    int *exp_b = kp_stack_pop(&stack);
    XCTAssert(*exp_b == b);

    int *exp_a = kp_stack_pop(&stack);
    XCTAssert(*exp_a == a);
}

- (void)testIntegrityOfAnnotationTree {
    NSArray *annotations = dataset2_random_NY_and_SF();

    NSUInteger annotationsCount = annotations.count;

    NSLog(@"Annotation Count: %tu", annotationsCount);

    KPAnnotationTree *annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    NSArray *annotationsBySearch = [annotationTree annotationsInMapRect:MKMapRectWorld];

    XCTAssertTrue(NSArrayHasDuplicates(annotationsBySearch) == NO);

    __block NSUInteger numberOfNodes = 0;

    void (^traversalBlock)(kp_treenode_t *, int) = ^(kp_treenode_t *node, int level) {
        NSUInteger XorY = (level % 2) == 0;

        if (node->left) {
            if (XorY) {
                XCTAssertTrue(node->left->mapPoint.x < node->mapPoint.x, @"");
            } else {
                XCTAssertTrue(node->left->mapPoint.y < node->mapPoint.y, @"");
            }
        }

        if (node->right) {
            if (XorY) {
                XCTAssertTrue(node->mapPoint.x <= node->right->mapPoint.x, @"");
            } else {
                XCTAssertTrue(node->mapPoint.y <= node->right->mapPoint.y, @"");
            }
        }
    };

    kp_stack_el_t *stack_info_storage = malloc(annotationsCount * sizeof(kp_stack_el_t));
    kp_stack_el_t *top_snaphot;

    kp_stack_t stack = kp_stack_create(annotationsCount);
    kp_stack_push(&stack, NULL);

    kp_stack_el_t *top = stack_info_storage;
    top->node = annotationTree.tree.root;
    top->level = 0;

    while (top != NULL) {
        numberOfNodes++;

        kp_treenode_t *node = top->node;

        traversalBlock(top->node, top->level);

        top_snaphot = top;

        if (node->right != NULL) {
            top++;

            (top)->node = node->right;
            (top)->level = top_snaphot->level + 1;;

            kp_stack_push(&stack, top);
        }

        if (node->left != NULL) {
            top++;

            (top)->node = node->left;
            (top)->level = top_snaphot->level + 1;;

            kp_stack_push(&stack, top);
        }

        top = kp_stack_pop(&stack);
    }

    NSLog(@"numberOfNodes Count: %tu", numberOfNodes);

    XCTAssertTrue(annotationsCount == annotations.count, @"");
    XCTAssertTrue(annotationsCount == annotationsBySearch.count, @"");
    XCTAssertTrue(annotationsCount == numberOfNodes, @"");
}

- (void)testEquivalenceOfAnnotationTrees {
    NSArray *annotations = dataset3_5000_equal_points();

    NSUInteger annotationsCount = annotations.count;

    // Create array of shuffled annotations and ensure integrity.
    NSArray *shuffledAnnotations = arrayShuffle(annotations);

    NSAssert(annotations.count == shuffledAnnotations.count, nil);

    NSSet *annotationSet = [NSSet setWithArray:annotations];
    NSSet *shuffledAnnotationSet = [NSSet setWithArray:shuffledAnnotations];

    NSAssert([annotationSet isEqual:shuffledAnnotationSet], nil);


    // Build to two different trees based on original and shuffled annotations arrays.
    KPAnnotationTree *annotationTree1 = [[KPAnnotationTree alloc] initWithAnnotations:annotations];
    KPAnnotationTree *annotationTree2 = [[KPAnnotationTree alloc] initWithAnnotations:shuffledAnnotations];

    NSArray *annotationsBySearch1 = [annotationTree1 annotationsInMapRect:MKMapRectWorld];
    NSArray *annotationsBySearch2 = [annotationTree2 annotationsInMapRect:MKMapRectWorld];

    XCTAssertTrue(NSArrayHasDuplicates(annotationsBySearch1) == NO);
    XCTAssertTrue(NSArrayHasDuplicates(annotationsBySearch2) == NO);

    NSSet *annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    NSSet *annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], @"");
    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSet], @"");
    XCTAssertTrue(annotationsBySearch1.count == annotationsCount, @"");

    // Create random rect
    MKMapRect randomRect = MKMapRectRandom();

    NSAssert(MKMapRectContainsRect(MKMapRectWorld, randomRect), nil);

    annotationsBySearch1 = [annotationTree1 annotationsInMapRect:randomRect];
    annotationsBySearch2 = [annotationTree2 annotationsInMapRect:randomRect];

    annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], @"");
}

@end
