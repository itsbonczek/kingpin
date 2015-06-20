# Kingpin FAQ

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [How to access cluster's annotations?](#how-to-access-clusters-annotations)
- [How to disable clustering at a certain zoom level (multiple pins at same location)?](#how-to-disable-clustering-at-a-certain-zoom-level-multiple-pins-at-same-location)
- [How to configure annotations with custom images?](#how-to-configure-annotations-with-custom-images)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

### How to access cluster's annotations?

You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

### How to disable clustering at a certain zoom level (multiple pins at same location)?

The simplest solution that worked for everyone so far:

Find category for MKMapView which provides you with zoom level ([one example](https://github.com/johndpope/MKMapViewZoom)).

Then implement clustering controller's delegate method:

```objective-c
- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController {
    return self.mapView.zoomLevel < 14; // Find zoom level that suits your dataset
}
```

### How to configure annotations with custom images?

__Note:__ Notice that in the following example __it is `MKAnnotationView` class__ that should be used as class or parent class for annotations with custom images, __not the `MKPinAnnotationView` !__ which is intended to work specifically with default annotation pin icons provided by Apple. 

```objective-c
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {    
    MKAnnotationView *annotationView = nil;
    
    if ([annotation isKindOfClass:[KPAnnotation class]]) {
        KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
        
        if ([kingpinAnnotation isCluster]) { 
            annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if (annotationView == nil){
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];

                annotationView.canShowCallout = YES;

                annotationView.image = [UIImage imageNamed:@"blue"];
            }
        }

        else {
            annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
            
            if (annotationView == nil) {
                annotationView = [[MKAnnotationView alloc] initWithAnnotation:[kingpinAnnotation.annotations anyObject]
                                                              reuseIdentifier:@"pin"];

                annotationView.canShowCallout = YES;

                annotationView.image = [UIImage imageNamed:@"green"];
            }
        }
    }

    return annotationView;
}
```


