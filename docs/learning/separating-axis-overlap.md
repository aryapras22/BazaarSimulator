# Separating axis overlap for boxes and ovals

`LayoutGeometry.intersects` and `LayoutGeometry.overlapDepth` decide whether two footprints overlap and by how much. The validator uses the depth to warn about booths that run into each other or into a column, with a 0.1 m tolerance. Footprints can be turned boxes or turned ovals, so the test has to work for any pair of convex shapes.

## What it is

The separating axis theorem says two convex shapes do not overlap exactly when some line exists that you can project both shapes onto and get two intervals that do not touch. For convex polygons you never have to search for that line. It is always perpendicular to one of the edges of one of the two polygons. So the test is: for every edge normal of either polygon, project both polygons onto it and compare the intervals. One gap means no overlap. No gap on any normal means overlap, and the smallest shared interval length is how deep they overlap.

## Why this and not something else

A bounding box test is cheap but wrong for turned boxes and for ovals: a round column next to the corner of a booth has a bounding box that hits the booth while the circle itself misses it. An exact oval against box test needs a numeric root search for each pair. Turning each oval into a 32-point polygon keeps one test for every pair of shapes, and the error is small. A 32-sided polygon inscribed in a circle reaches about 99.5 percent of the radius, so a 1 m column is under by about 2.5 mm, far below the validator's 0.1 m tolerance.

The cost is axes: a box has two distinct edge normals (opposite edges share one), a 32-gon has 32. A box against an oval tests 34 axes instead of 4. The validator only runs the test on pairs whose bounding boxes are already close, so this stays cheap.

## How it works, step by step

1. `outline(of:)` turns a placement into a polygon. A rectangle gives its four turned corners. A round placement gives 32 points `(rx cos t, ry sin t)` around its centre, turned by the placement's rotation, where `rx` and `ry` are half the width and length.
2. `separatingAxes(for:)` takes each edge `b - a`, turns it a quarter to get its normal `(-dy, dx)`, and scales it to length 1. For a rectangle it stops after two edges, because the other two are parallel to them.
3. `project` takes the dot product of every point with the axis and keeps the smallest and largest, giving an interval on that axis.
4. `intersects` returns false as soon as one axis shows a gap. Touching edges count as a gap, so booths placed edge to edge do not overlap.
5. `overlapDepth` keeps the smallest shared length over all axes. That is how far you would have to push one shape to separate them, and it is negative or zero when they are apart.

Point containment does not use this. `contains` maps the point into the placement's own frame, then checks `|x| <= w/2` and `|y| <= h/2` for a box, or `(x / (w/2))^2 + (y / (h/2))^2 <= 1` for an oval.

## Terms

- Convex: every straight line between two points of the shape stays inside it. Boxes and ovals are convex; an L-shaped booth is not.
- Projection: the dot product of a point with a unit axis, its shadow on that line.
- Edge normal: a direction at right angles to an edge.
- Inscribed polygon: a polygon whose corners sit on the curve, so it lies just inside it.

## Pitfalls

- The theorem holds only for convex shapes. An L-shaped footprint must be split into convex pieces first.
- The axes must be normals, not edge directions. Projecting onto the edges themselves gives wrong answers for turned boxes.
- Leaving an axis unnormalised still finds the gap but makes the depth wrong, because interval lengths scale with the axis length.
- Dropping duplicate axes is safe only for shapes whose opposite edges are parallel. The two-axis shortcut is right for a box and wrong for a 32-gon, which is why it applies only to four-point outlines.
- An inscribed polygon slightly underestimates overlap. Where a miss matters more than a false alarm, use a circumscribed polygon by scaling the radii up by `1 / cos(pi / n)`.

## Further reading

- Gottschalk, Lin and Manocha, "OBBTree: A Hierarchical Structure for Rapid Interference Detection", SIGGRAPH 1996, section 4, the separating axis test for oriented boxes: https://doi.org/10.1145/237170.237244
- Eberly, "Dynamic Collision Detection using Oriented Bounding Boxes", Geometric Tools: https://www.geometrictools.com/Documentation/DynamicCollisionDetection.pdf
