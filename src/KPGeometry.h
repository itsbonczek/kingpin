//
//  KPGeometry.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 13/04/14.
//
//

#ifndef kingpin_KPGeometry_h
#define kingpin_KPGeometry_h


static inline MKMapRect MKMapRectNormalizeToCellSize(MKMapRect mapRect, MKMapSize cellSize) {
    MKMapRect normalizedRect = mapRect;

    normalizedRect.origin.x -= ceil(fmod(normalizedRect.origin.x, cellSize.width));
    normalizedRect.origin.y -= ceil(fmod(normalizedRect.origin.y, cellSize.height));

    normalizedRect.size.width  += ceil((cellSize.width  - fmod(normalizedRect.size.width, cellSize.width)));
    normalizedRect.size.height += ceil((cellSize.height - fmod(normalizedRect.size.height, cellSize.height)));

    NSLog(@"normalized rect %f %f", normalizedRect.size.width,  normalizedRect.size.height);

    NSLog(@"grid %% cell: %f, %f", fmod(normalizedRect.size.width, cellSize.width), fmod(normalizedRect.size.height, cellSize.height));

    assert(((uint32_t)normalizedRect.size.width  % (uint32_t)cellSize.width)  == 0);
    assert(((uint32_t)normalizedRect.size.height % (uint32_t)cellSize.height) == 0);

    return normalizedRect;
}


#endif
