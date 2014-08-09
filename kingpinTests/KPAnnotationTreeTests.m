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

#import "kp_stack.h"

@interface KPAnnotationTreeTests : XCTestCase
@end

typedef struct {
    kp_treenode_t *node;
    int idx;
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

    void (^traversalBlock)(kp_treenode_t *node) = ^(kp_treenode_t *node) {
        NSUInteger XorY = (node->level % 2) == 0;

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
    for (int i = 0; i < annotationsCount; i++) {
        stack_info_storage[i].idx = i;
    }
    kp_stack_el_t *stack_info_iterator = stack_info_storage;

    kp_stack_t stack = kp_stack_create(annotationsCount);
    kp_stack_push(&stack, NULL);

    annotationTree.root->level = 0;

    kp_stack_el_t *top = stack_info_iterator;
    top->node = annotationTree.root;

    while (top != NULL) {
        printf("idx %d\n", top->idx);

        numberOfNodes++;

        kp_treenode_t *node = top->node;

        traversalBlock(node);

        if (node->right != NULL) {
            stack_info_iterator++;

            node->right->level = node->level + 1;

            (stack_info_iterator)->node = node->right;

            kp_stack_push(&stack, stack_info_iterator);
        }

        if (node->left != NULL) {
            stack_info_iterator++;

            node->left->level = node->level + 1;

            (stack_info_iterator)->node = node->left;

            kp_stack_push(&stack, stack_info_iterator);
        }

        stack_info_iterator--;
        top = kp_stack_pop(&stack);
    }

    NSLog(@"numberOfNodes Count: %tu", numberOfNodes);

    XCTAssertTrue(annotationsCount == annotations.count, @"");
    XCTAssertTrue(annotationsCount == annotationsBySearch.count, @"");
    XCTAssertTrue(annotationsCount == numberOfNodes, @"");
}

- (void)testEquivalenceOfAnnotationTrees {
    NSArray *annotations = dataset2_random_NY_and_SF();

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
