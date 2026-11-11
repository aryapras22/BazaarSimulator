# Dijkstra distance fields on a grid

## What it is

`NavigationGrid` computes, for one goal cell, the cheapest walking cost from every cell on the floor to that goal. That table is a distance field. It uses Dijkstra's algorithm with a binary min-heap as the priority queue.

## Why this and not plain BFS

Breadth-first search finds the fewest moves. That equals the cheapest route only when every move costs the same. Here a straight move costs 10 and a diagonal costs 14, so the first route to reach a cell may not be its cheapest, and BFS never revisits it. In a model of the old code on floors with obstacles, about 0.6% of routes came out longer, typically by 4% and at worst by 10%.

A distance field is computed once per goal and cached, so many visitors heading to the same booth share one search. A* would be faster for one route, but it answers only one start at a time. The cost of this choice is log-time heap operations and a full-floor table per goal.

## How it works

1. Set every cell's cost to unknown and the goal's cost to 0. Put the goal in the heap.
2. Take the cell with the lowest cost out of the heap.
3. If the popped cost differs from the cell's recorded cost, this entry is out of date. Skip it.
4. For each legal neighbour, add the step cost. If that total beats the neighbour's recorded cost, record it and push the neighbour.
5. Repeat until the heap is empty.

Step costs are never negative, so nothing found later can beat the lowest entry in the heap. That is why a cell's cost is final when its current entry is popped.

To walk a route, stand on the start cell and repeatedly move to the neighbour with the lowest step cost plus remaining cost. That sum always equals the current cell's cost on a shortest route, so the walk always makes progress.

## Terms

Distance field: a table giving each cell's cost to reach one goal. Frontier: the cells discovered but not yet finalised, held in the heap. Binary min-heap: an array arranged as a tree where each parent is no larger than its children, giving the smallest item in log time. Stale entry: an older heap entry for a cell that has since found a cheaper route.

## Pitfalls

Choosing the neighbour with the lowest remaining cost alone is wrong. A diagonal neighbour can be slightly closer to the goal and still cost more once the 14 for the step is added.

Using 10 and 14 instead of 1 and the square root of 2 keeps arithmetic exact. The ratio 1.4 is close to 1.414, and routes come out the same on this grid unless costs nearly tie.

Unreached cells hold -1 here, so any comparison has to check for that before treating the value as a cost.

## Further reading

E. W. Dijkstra, "A note on two problems in connexion with graphs", Numerische Mathematik 1 (1959): https://doi.org/10.1007/BF01386390

J. W. J. Williams, "Algorithm 232: Heapsort", Communications of the ACM 7(6) (1964): https://doi.org/10.1145/512274.512284
