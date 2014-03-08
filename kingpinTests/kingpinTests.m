//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import "KPAnnotationTree.h"
#import "KPAnnotationTree_Private.h"

#import "TestAnnotation.h"

@interface kingpinTests : SenTestCase

@end

static NSUInteger const kNumberOfTestAnnotations = 10000;

@implementation kingpinTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIntegrityOfAnnotationTree
{
    // build an NYC and SF cluster

    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D SFCoord = CLLocationCoordinate2DMake(37.85, -122.68);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;
    CLLocationCoordinate2D sfCoord = SFCoord;

    for (int i=0; i < kNumberOfTestAnnotations / 2; i++) {

        CLLocationDegrees latAdj = ((random() % 100) / 1000.f);
        CLLocationDegrees lngAdj = ((random() % 100) / 1000.f);

        TestAnnotation *a1 = [[TestAnnotation alloc] init];
        a1.coordinate = CLLocationCoordinate2DMake(nycCoord.latitude + latAdj,
                                                   nycCoord.longitude + lngAdj);
        [annotations addObject:a1];

        TestAnnotation *a2 = [[TestAnnotation alloc] init];
        a2.coordinate = CLLocationCoordinate2DMake(sfCoord.latitude + latAdj,
                                                   sfCoord.longitude + lngAdj);
        [annotations addObject:a2];

    }

    KPAnnotationTree *annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    NSArray *annotationsBySearch = [annotationTree annotationsInMapRect:MKMapRectWorld];

    __block __weak void (^weakRecursiveTraversalBlock)(KPTreeNode *node, NSUInteger levelOfDepth);
    void (^recursiveTraversalBlock)(KPTreeNode *node, NSUInteger levelOfDepth);

    __block NSUInteger numberOfNodes = 0;

    weakRecursiveTraversalBlock = recursiveTraversalBlock = ^(KPTreeNode *node, NSUInteger levelOfDepth) {
        numberOfNodes++;

        NSUInteger XorY = (levelOfDepth % 2) == 0;

        if (node.left) {
            if (XorY) {
                STAssertTrue(node.left.mapPoint.x < node.mapPoint.x, nil);
            } else {
                STAssertTrue(node.left.mapPoint.y < node.mapPoint.y, nil);
            }

            weakRecursiveTraversalBlock(node.left, levelOfDepth + 1);
        }

        if (node.right) {
            if (XorY) {
                STAssertTrue(node.mapPoint.x <= node.right.mapPoint.x, nil);
            } else {
                STAssertTrue(node.mapPoint.y <= node.right.mapPoint.y, nil);
            }

            weakRecursiveTraversalBlock(node.right, levelOfDepth + 1);
        }
    };

    recursiveTraversalBlock(annotationTree.root, 0);

    STAssertTrue(kNumberOfTestAnnotations == annotations.count, nil);
    STAssertTrue(kNumberOfTestAnnotations == annotationsBySearch.count, nil);
    STAssertTrue(kNumberOfTestAnnotations == numberOfNodes, nil);
}

@end
