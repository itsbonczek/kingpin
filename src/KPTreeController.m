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

#import "KPTreeController.h"

#import "KPAnnotation.h"
#import "KPAnnotationTree.h"

@interface KPTreeController()

@property (nonatomic) MKMapView *mapView;
@property (nonatomic) KPAnnotationTree *annotationTree;

@end

@implementation KPTreeController

- (id)initWithMapView:(MKMapView *)mapView {
    
    self = [super init];
    
    if(self){
        self.mapView = mapView;
        self.gridSize = CGSizeMake(80.f, 80.f);
        self.animationDuration = 0.5f;
    }
    
    return self;
    
}

- (void)setAnnotations:(NSArray *)annoations {
    self.annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annoations];
}

- (void)refresh:(BOOL)animated {
    [self _updateVisibileMapAnnotationsOnMapView:animated];
}


#pragma mark - Private

- (void)_updateVisibileMapAnnotationsOnMapView:(BOOL)animated
{
    
    NSMutableArray *newClusters = [NSMutableArray array];
    NSMutableArray *oldClusters = [NSMutableArray array];
    
    for(int x = 0; x < self.mapView.frame.size.width; x += self.gridSize.width){
        
        for(int y = 0; y < self.mapView.frame.size.height; y += self.gridSize.height){
            
            MKMapRect gridRect = [self _mapView:self.mapView
                              mapRectFromCGRect:CGRectMake(x, y, self.gridSize.width, self.gridSize.height)];
            
            NSArray *existingAnnotations = [[self.mapView annotationsInMapRect:gridRect] allObjects];
            NSArray *newAnnotations = [self.annotationTree annotationsInMapRect:gridRect];
            
            [oldClusters addObjectsFromArray:existingAnnotations];
            
            if(newAnnotations.count){
                KPAnnotation *a = [[KPAnnotation alloc] initWithAnnotations:newAnnotations];
                [newClusters addObject:a];
            }
        }
    }
    
    if(animated){
        
        for(KPAnnotation *newCluster in newClusters){
            
            [self.mapView addAnnotation:newCluster];
            
            for(KPAnnotation *oldCluster in oldClusters){
                if([oldCluster.annotations member:[newCluster.annotations anyObject]]){
                    [self _animateCluster:newCluster
                           fromCoordinate:oldCluster.coordinate
                             toCoordinate:newCluster.coordinate
                               completion:nil];
                    [self.mapView removeAnnotation:oldCluster];
                }
                else if([newCluster.annotations member:[oldCluster.annotations anyObject]]){
                    [self _animateCluster:oldCluster
                           fromCoordinate:oldCluster.coordinate
                             toCoordinate:newCluster.coordinate
                               completion:^(BOOL finished) {
                                   [self.mapView removeAnnotation:oldCluster];
                               }];
                }
            }
        }

    }
    else {
        [self.mapView removeAnnotations:oldClusters];
        [self.mapView addAnnotations:newClusters];
    }
        
}

- (MKMapRect)_mapView:(MKMapView *)mapView mapRectFromCGRect:(CGRect)rect {
    
    CLLocationCoordinate2D topLeftCoord = [mapView convertPoint:CGPointMake(rect.origin.x, rect.origin.y)
                                           toCoordinateFromView:mapView];
    
    CLLocationCoordinate2D bottomRightCorod = [mapView convertPoint:CGPointMake(rect.origin.x + rect.size.width,
                                                                                rect.origin.y + rect.size.height)
                                               toCoordinateFromView:mapView];
    
    MKMapPoint topLeftPoint = MKMapPointForCoordinate(topLeftCoord);
    MKMapPoint bottomRightPoint = MKMapPointForCoordinate(bottomRightCorod);
    
    MKMapRect gridRect = MKMapRectMake(topLeftPoint.x,
                                       topLeftPoint.y,
                                       bottomRightPoint.x - topLeftPoint.x,
                                       bottomRightPoint.y - topLeftPoint.y);
    
    return gridRect;
    
}

- (void)_animateCluster:(KPAnnotation *)cluster
         fromCoordinate:(CLLocationCoordinate2D)fromCoord
           toCoordinate:(CLLocationCoordinate2D)toCoord
             completion:(void (^)(BOOL finished))completion
{
    
    cluster.coordinate = fromCoord;
    
    [UIView animateWithDuration:self.animationDuration
                          delay:0.f
                        options:self.animationOptions
                     animations:^{
                         cluster.coordinate = toCoord;
                     }
                     completion:completion];
    
}


@end
