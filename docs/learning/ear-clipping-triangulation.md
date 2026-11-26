# Ear clipping triangulation

The GPU draws only triangles, so a floor shaped like any polygon has to be cut into triangles first. `Core/Domain/PolygonTriangulator.swift` does that with ear clipping, and both 3D paths use it: `TriangleMesh.appendFloorPolygon` (SceneKit scene) and `MeshData.floorSlab` (Metal renderer).

## Why it was chosen

The old code used a triangle fan: connect vertex 0 to every other edge. A fan is only correct for convex polygons. Once the hall can have a notch, some fan triangles cross the notch and the floor fills an area that is not hall. Ear clipping handles any simple polygon (no self-crossings, no holes). It costs O(n²) in the number of vertices, which is nothing for a hall with a few dozen corners. Faster methods (monotone decomposition, O(n log n)) are much more code and only pay off for thousands of vertices. Libraries such as earcut add a dependency, which the project avoids.

## How it works

1. Work out the winding. The signed area (shoelace formula) is positive for counter-clockwise order. If it is negative, walk the vertices in reverse so the rest of the algorithm can assume counter-clockwise.
2. Remove repeated points and points that sit on a straight line between their neighbours. They make zero-area triangles.
3. Look for an ear: three consecutive vertices prev, curr, next where the corner at curr is convex (the cross product of `curr - prev` and `next - curr` is positive for counter-clockwise order) and no other vertex of the polygon lies inside the triangle prev-curr-next.
4. Cut the ear off: emit that triangle and delete curr from the ring. The ring is now one vertex shorter and still a simple polygon.
5. Repeat until three vertices remain; they form the last triangle.

Every simple polygon with more than three vertices has at least two ears (Meisters' two ears theorem), so step 3 always finds one when the input is valid. The fallbacks in the code (drop a collinear vertex, then accept an ear whose triangle only touches the boundary) cover floating point edge cases where the strict test finds nothing.

## Terms

- Simple polygon: its edges meet only at shared corners and never cross.
- Convex vertex: the interior angle there is under 180 degrees. Reflex vertex: over 180 degrees, as at the inner corners of a notch.
- Ear: a convex vertex whose triangle with its two neighbours contains no other vertex.
- Winding: the order the corners are listed, clockwise or counter-clockwise. It decides which way a triangle faces, and so whether the GPU draws its front.

## Pitfalls

- A reflex vertex is never an ear. Treating it as one creates a triangle outside the polygon, which is exactly the notch bug the fan had.
- Testing only whether other vertices are strictly inside the candidate triangle misses vertices lying on its edge. Collinear points left in the ring are the usual cause.
- Floating point: use a small epsilon in the convexity and inside tests, or nearly flat corners flip between convex and reflex.
- Holes are not supported. A hall with an island in the middle needs a bridge edge to the hole first, which this code does not do.

## Further reading

- Meisters, G. H. "Polygons have ears." American Mathematical Monthly 82 (1975): 648–651.
- Eberly, D. "Triangulation by Ear Clipping." Geometric Tools, https://www.geometrictools.com/Documentation/TriangulationByEarClipping.pdf
- de Berg, Cheong, van Kreveld, Overmars. Computational Geometry: Algorithms and Applications, 3rd ed., chapter 3 (polygon triangulation).
