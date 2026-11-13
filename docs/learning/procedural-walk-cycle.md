# Procedural walk cycle

The 3D simulator's people walk without any stored animation. Each figure's pose is computed every frame from one small piece of state per visitor, `FigureGait` in `Features/Analysis/Scene/FigureGait.swift`.

## Why this technique

The usual way to animate a character is a skeleton with keyframed clips, blended by an animation system. That needs rigged models and a per-character animation state, which is far more than a crowd of capsule figures warrants. A procedural cycle needs no assets and costs a few sines per visitor. The price is that it only does one thing: a plain walk, with no sitting, queueing or gestures.

## How it works

1. The simulation only gives a position per visitor per frame. The gait remembers the last position, so it can tell how far the visitor moved and how fast.
2. Heading: the direction of travel is `atan2(dx, dz)` of the move since the last anchor point. The anchor only moves on once the visitor has gone 2 cm, so slow steps add up instead of producing noise. The figure does not snap to the new direction. It turns toward it by the shortest way, at most `turnRate` radians a second.
3. Phase: a number that runs from 0 to 2π over one stride (two steps). While the visitor moves, phase advances by `2π × strides per second × seconds`. Strides per second is speed divided by stride length, clamped to a walking range. The clamp matters because playback is fast-forwarded: a visitor may cross 30 m of floor in a second, and legs cycling at that rate would strobe.
4. Walk amount: a number from 0 to 1 that rises while the visitor moves and falls while it stands, over a fifth of a second. Every swing is multiplied by it, so a figure eases into a walk and comes to rest with its legs straight.
5. Pose: the left leg leans by `sin(phase) × legSwing × walk`, the right leg by the opposite, and each arm opposite to the leg on its side. The body and head rise by `|sin(phase)|`, once per step.
6. Pivot: the renderer can only lean a shape about its own middle. A leg should swing from the hip, so the code moves the leg's middle to where it would be if the leg hung from the hip at that angle: half a leg length down and back along the lean. The vertex shader then applies the lean (`tilt.x`) before turning the shape to its heading.

## Terms

- Phase: where in a repeating cycle something is, as an angle.
- Cadence: steps or strides per second.
- Easing: moving a value toward its target a little each frame instead of at once.
- Frame-rate independence: every rate is multiplied by the seconds since the last frame, so the motion is the same at 30 or 120 frames a second.

## Pitfalls

- A long gap between frames (a pause, or the window hidden) must not count as one huge step. The seconds per frame are capped at 0.1.
- Scrubbing the timeline moves visitors many meters at once. A move over 3 m is treated as a jump, not a step.
- Angles wrap. Turning from 3.0 to -3.0 radians is a short turn through π, not a long one through zero, so the difference is wrapped into -π to π first.
- The view only redraws when the simulation hands it a new frame or the camera moves, so a paused simulation freezes figures mid-stride.

## Further reading

- Metal Shading Language Specification, for the vertex function that applies the lean: https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
- Apple, `CACurrentMediaTime`: https://developer.apple.com/documentation/quartzcore/cacurrentmediatime()
