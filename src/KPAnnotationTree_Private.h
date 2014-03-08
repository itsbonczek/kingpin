//
//  KPAnnotationTree_Private.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "KPAnnotationTree.h"
#import "KPTreeNode.h"

@interface KPAnnotationTree ()

@property (nonatomic) KPTreeNode *root;
@property (nonatomic, readwrite) NSSet *annotations;

@end
