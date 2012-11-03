kingpin
=======

### A drop-in MKAnnotation clustering library for iOS


features
---------

* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance 
* No subclassing required, making the library easy to integrate with existing projects.


usage
-----

Create an instance of a KPTreeController:

`self.treeController = [[KPTreeController alloc] initWithMapView:self.mapView]`

Set the controller's annotations:

`[self.treeController setAnnotations:[self annotations]];`

Handle the clusters:

```
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    KPAnnotation *a = (KPAnnotation *)annotation;
    
    MKPinAnnotationView *v = 
      (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
    
    if(!v){
        v = [[MKPinAnnotationView alloc] initWithAnnotation:a reuseIdentifier:@"pin"];
    }
    
    v.pinColor = (a.annotations.count > 1 ? MKPinAnnotationColorPurple : MKPinAnnotationColorRed);
    
    return v;
    
}
```

Note: You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

Refresh visible annotations as needed:

```
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.treeController refresh:self.animationSwitch.on];
}
```

This is typically done in `-mapView:regionDidChangeAnimated:`

demo
----

Check out the **tester** target in *kingpin.xcodeproj*
