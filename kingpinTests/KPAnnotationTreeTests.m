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


@interface KPAnnotationTreeTests : XCTestCase
@end

static NSUInteger const kNumberOfTestAnnotations = 50000;

@implementation KPAnnotationTreeTests

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

    for (int i = 0; i < kNumberOfTestAnnotations / 2; i++) {

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

    XCTAssertTrue(kNumberOfTestAnnotations == annotations.count, @"");
    XCTAssertTrue(kNumberOfTestAnnotations == annotationsBySearch.count, @"");
    XCTAssertTrue(kNumberOfTestAnnotations == numberOfNodes, @"");
}

- (void)testEquivalenceOfAnnotationTrees
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

    NSSet *annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    NSSet *annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], @"");
    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSet], @"");
    XCTAssertTrue(annotationsBySearch1.count == kNumberOfTestAnnotations, @"");

    // Create random rect
    double randomWidth = randomWithinRange(0, MKMapRectWorld.size.width);
    double randomHeight = randomWithinRange(0, MKMapRectWorld.size.height);
    double randomX = randomWithinRange(0, MKMapRectWorld.size.width - randomWidth);
    double randomY = randomWithinRange(0, MKMapRectWorld.size.height - randomHeight);

    MKMapRect randomRect = MKMapRectMake(randomX, randomY, randomWidth, randomHeight);

    NSAssert(MKMapRectContainsRect(MKMapRectWorld, randomRect), nil);

    annotationsBySearch1 = [annotationTree1 annotationsInMapRect:randomRect];
    annotationsBySearch2 = [annotationTree2 annotationsInMapRect:randomRect];

    annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    XCTAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], @"");
}

@end
