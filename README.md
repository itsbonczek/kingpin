# kingpin

A drop-in MKAnnotation clustering library for iOS.

[![Build Status](https://travis-ci.org/itsbonczek/kingpin.svg?branch=master)](https://travis-ci.org/itsbonczek/kingpin)


## Features


* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance.
* No subclassing required, making the library easy to integrate with existing projects.


## Usage

Create an instance of a KPTreeController:

```objective-c
self.treeController = [[KPTreeController alloc] initWithMapView:self.mapView]
```

Set the controller's annotations:

```objective-c
[self.treeController setAnnotations:[self annotations]];
```

Handle the clusters:

```objective-c
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    MKPinAnnotationView *annotationView = nil;
    
    if ([annotation isKindOfClass:[KPAnnotation class]]) {
        KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
        
        if ([kingpinAnnotation isCluster]) {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorPurple;
        } else {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:[kingpinAnnotation.annotations anyObject] reuseIdentifier:@"pin"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorRed;
        }
        
        annotationView.canShowCallout = YES;
    }
    
    return annotationView;
}
```

Also, see example on how to use kingpin with your own custom annotations in [Wiki/Examples](https://github.com/itsbonczek/kingpin/wiki/Examples).

__Note:__ You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

Refresh visible annotations as needed:

```objective-c
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.treeController refresh:self.animationSwitch.on];
}
```

This is typically done in `-mapView:regionDidChangeAnimated:`

## Versions

See [CHANGELOG](https://github.com/itsbonczek/kingpin/blob/master/CHANGELOG.md) for details. All versions are tagged accordingly.

## Demo

Check out the **tester** target in *kingpin.xcodeproj*

## Licence

Apache 2.0

