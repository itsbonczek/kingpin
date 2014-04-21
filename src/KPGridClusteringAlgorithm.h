

#import <Foundation/Foundation.h>


@class KPAnnotation, KPAnnotationTree;
@protocol KPGridClusteringAlgorithmDelegate;


@interface KPGridClusteringAlgorithm : NSObject
@property (weak, nonatomic) id <KPGridClusteringAlgorithmDelegate> delegate;

- (NSArray *)performClusteringOfAnnotationsInMapRect:(MKMapRect)mapRect cellSize:(MKMapSize)cellSize annotationTree:(KPAnnotationTree *)annotationTree;

@end
