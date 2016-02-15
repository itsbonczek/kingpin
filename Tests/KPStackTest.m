//
//  KPStackTest.m
//  kingpin-dev
//
//  Created by Stanislaw Pankevich on 15/02/16.
//
//

#import "TestHelpers.h"

#import "KPAnnotationTree.h"
#import "KPAnnotationTree_Private.h"

#import "TestAnnotation.h"

@interface KPStackTest : XCTestCase
@end

@implementation KPStackTest

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

@end
