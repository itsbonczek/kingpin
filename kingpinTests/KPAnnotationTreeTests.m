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

@implementation KPAnnotationTreeTests

- (void)testIntegrityOfAnnotationTree {
    NSArray *annotations = dataset2_random_NY_and_SF();

    NSUInteger annotationsCount = annotations.count;

    NSLog(@"Annotation Count: %zu", annotationsCount);

    KPAnnotationTree *annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    NSArray *annotationsBySearch = [annotationTree annotationsInMapRect:MKMapRectWorld];

    XCTAssertTrue(NSArrayHasDuplicates(annotationsBySearch) == NO);
    
    __block __weak void (^weakRecursiveTraversalBlock)(kp_treenode_t *node, NSUInteger levelOfDepth);
    void (^recursiveTraversalBlock)(kp_treenode_t *node, NSUInteger levelOfDepth);

    __block NSUInteger numberOfNodes = 0;

    weakRecursiveTraversalBlock = recursiveTraversalBlock = ^(kp_treenode_t *node, NSUInteger levelOfDepth) {
        numberOfNodes++;

        NSUInteger XorY = (levelOfDepth % 2) == 0;

        if (node->left) {
            if (XorY) {
                XCTAssertTrue(node->left->mapPoint.x < node->mapPoint.x, @"");
            } else {
                XCTAssertTrue(node->left->mapPoint.y < node->mapPoint.y, @"");
            }

            weakRecursiveTraversalBlock(node->left, levelOfDepth + 1);
        }

        if (node->right) {
            if (XorY) {
                XCTAssertTrue(node->mapPoint.x <= node->right->mapPoint.x, @"");
            } else {
                XCTAssertTrue(node->mapPoint.y <= node->right->mapPoint.y, @"");
            }

            weakRecursiveTraversalBlock(node->right, levelOfDepth + 1);
        }
    };

    recursiveTraversalBlock(annotationTree.root, 0);

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
