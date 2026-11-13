# Ink outlines and flat tones in a fragment shader

The 3D simulator draws the venue like an ink illustration: each face is one flat color, faces turned from the light are hatched, and every edge is a dark line. All of it happens in `solidFragment` in `Metal3DShaderSource.swift`, in the same single pass that already drew the venue. There is no second render pass and no extra geometry.

## Why this technique

The usual ways to outline 3D shapes are an inverted hull (draw each mesh a second time, scaled up, in black, with front faces culled) or a post-process edge filter over a depth and normal buffer. The hull only gives silhouettes, not the creases between a box's faces, and it doubles the draw calls. The post-process filter needs extra render targets and a second pass. Every venue shape here is a unit box or a unit cylinder that an instance stretches, so the shader can work out analytically how far a pixel is from an edge of its own shape. The cost is that lines belong to shapes, not to the picture: two boxes that touch still show the line between them, and a line is drawn on one side of a silhouette only.

## How the box line works

1. The vertex shader passes three extra values to the fragment shader: the vertex position on the unit cube (`local`, each axis from -0.5 to 0.5), the unit normal before rotation (`localNormal`), and the instance's size in meters (`scale`).
2. For each axis, `(0.5 - abs(local)) * scale` is the distance in meters from this pixel to the nearest face on that axis.
3. `fwidth(local * scale)` is how many meters that coordinate changes from one pixel to the next. Dividing the distance by it turns meters into pixels, so the line keeps the same width on screen at any zoom.
4. On any face, one axis is always at distance zero: the axis the face looks along. Adding a large number on that axis (`abs(localNormal) * 1e5`) removes it. The smaller of the remaining two is the distance to the nearest edge of the face.
5. `smoothstep` around the line width turns that distance into ink coverage with a soft, antialiased rim.
6. A face only a few pixels wide would be all line. The shader measures the face's narrow side in pixels and thins the ink there so the face's color still shows.

## How the round line works

For cylinders and visitor capsules the outline is where the surface turns away from the eye. `abs(dot(normal, toCamera))` falls to zero there. Dividing it by its own `fwidth` again gives a distance in pixels. A cylinder also gets a rim around each end, measured the same way as a box edge: by radius on the caps and by height on the side.

## Flat tones and hatching

A face is one of three tones: full color if it faces up, slightly darker if it faces the light, darker still if it faces away. Faces turned away also get slanted hatch lines, placed by world position (`x + y + z`) so they stay fixed to the wall when the camera moves. When the lines would be closer together than the pixels, they fade out to avoid moire.

## Terms

- `fwidth(x)`: the sum of the absolute change of `x` to the next pixel across and the next pixel down. It answers "how much of x fits in one pixel here".
- Screen-space derivative: the general name for `dfdx`, `dfdy`, and `fwidth`. The GPU computes them by comparing neighbouring pixels of the same triangle.
- Flat interpolation (`[[flat]]`): a value passed to the fragment shader unchanged from one vertex, used here for the instance's size.
- Instance: one copy of a mesh with its own place, size, and color. One draw call draws all of them.

## Pitfalls

- Derivatives are only valid inside one triangle. A value that jumps between triangles, such as a per-face normal, gives a spike at the seam. The code only takes `fwidth` of values that vary smoothly across a face.
- The capsule mesh is not a unit shape, so the cylinder's rim test would ink its whole body. Visitors use the silhouette test alone, selected by the outline kind stored in `scale.w`.
- The hatch is in world space on purpose. A hatch placed by pixel position slides over the walls as the camera moves.
- The camera's field of view is narrow (about 26 degrees) to look axonometric. Distances that were tuned for a 60 degree view must be scaled by `tan(30°) / tan(fov / 2)`.

## Further reading

- Metal Shading Language Specification, section on derivative functions: https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
- OpenGL reference for `fwidth`: https://registry.khronos.org/OpenGL-Refpages/gl4/html/fwidth.xhtml
