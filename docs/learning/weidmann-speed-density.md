# Weidmann speed and density curve

## What it is

A formula for how much slower people walk as a space fills up. `CrowdSimulation.crowdFactor` uses it to scale each person's walking speed from the density around them.

## Why this and not a flat slowdown

Collision steering alone only makes people swerve, so a packed aisle would still move at full speed wherever a gap appears. Weidmann's curve comes from pedestrian measurements and gives a smooth fall from free walking to a crawl with two constants. The cost is that it was fitted to flowing crowds, so it says little about people browsing at a stall, and a floor of 0.08 keeps people from stopping dead.

## How it works

1. Count the people within 1.5 m, including yourself and counting a carried child, and leave out anyone seated.
2. Divide by the area of that circle to get density, in people per square metre.
3. Compute factor = 1 - exp(-1.913 x (1 / density - 1 / 5.4)).
4. Keep it between 0.08 and 1, and multiply walking speed by it.

At 1 person per square metre the factor is about 0.79. At the jam density of 5.4 the formula reaches zero, which is why the floor exists.

## Terms

Density: people per square metre around one person. Jam density: the density at which a flow stops, 5.4 here. Gamma: the constant that sets how quickly speed falls, 1.913 here. Fundamental diagram: the general name for speed, density and flow relationships.

## Pitfalls

The density here is a local count over about 7 square metres, so one person alone reads 0.14. Below 0.05 the code returns 1 directly, since the formula divides by density.

The heatmap's density and this density are different measurements. The heatmap smooths over a wider kernel and over time, so the two will not match at one spot.

## Further reading

U. Weidmann, "Transporttechnik der Fussgaenger", Schriftenreihe des IVT Nr. 90, ETH Zurich (1993). I did not verify a stable link for this report.
