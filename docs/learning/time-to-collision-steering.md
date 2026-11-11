# Time-to-collision steering

## What it is

A local avoidance method. Each person considers a small set of possible velocities, predicts how soon each one would run into a neighbour, and picks the cheapest. `CrowdSimulation+Movement.swift` uses it after the flow field has said where the person wants to go.

## Why this and not a repulsion force

A repulsion force pushes people apart based on where they are now. Two people walking side by side at 0.8 m get pushed apart even though they will never collide, and two people closing fast feel nothing until they are close. Time to collision looks at where people are going, so a head-on walker is avoided early and a parallel walker is ignored.

The cost is more work per person: 14 candidate velocities checked against up to 48 neighbours, which needs a spatial hash to stay affordable.

## How it works

1. Take the wanted velocity from the flow field or the group slot.
2. Build 14 candidates: seven headings around the wanted one, at full and half speed.
3. For each candidate, compute the time until the person's circle touches each neighbour's circle. Treat both as moving in straight lines, and use the candidate minus the neighbour's velocity as the relative motion.
4. Add up a cost: distance from the wanted velocity, a small charge for changing velocity, a term that grows as any collision gets sooner, and a charge for heading into a wall.
5. Keep the cheapest candidate, then ease the real velocity toward it over about 0.35 s.
6. After everyone moves, push apart any bodies that still overlap and push people off walls.

The time comes from a quadratic. With offset p, relative velocity v and combined radius R, the circles touch when |p - v t| = R. The smaller positive root of that equation is the collision time.

## Terms

Time to collision: seconds until two circles touch if both keep their current velocities. Combined radius: the sum of both body radii plus a comfort margin. Spatial hash: a coarse grid that lists who is in each bin, so a person only compares against nearby bins. Inertia: easing toward a new velocity so people do not turn instantly.

## Pitfalls

Halving the neighbour's velocity is deliberate. It assumes the neighbour will share the work of avoiding, and without it both sides over-correct.

Steering alone does not guarantee no overlap, because the choice is limited to 14 candidates. The push-apart step after moving is what keeps bodies from sharing space.

Parties standing still are given zero velocity and a larger comfort margin, so walkers route around a queue instead of squeezing through it.

## Further reading

I. Karamouzas, B. Skinner, S. J. Guy, "Universal power law governing pedestrian interactions", Physical Review Letters 113 (2014): https://doi.org/10.1103/PhysRevLett.113.238701
