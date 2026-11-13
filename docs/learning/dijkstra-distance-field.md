# Flow fields built with Dijkstra's algorithm

## What it is

`CrowdWorld` computes, for one target, the cheapest walking cost from every floor cell to that target, plus the direction to walk from each cell. That table is a flow field. It is built with Dijkstra's algorithm using a binary min-heap as the priority queue.

## Why this and not plain BFS or A*

Breadth-first search finds the fewest moves. That equals the cheapest route only when every move costs the same. Here a diagonal costs more than a straight step and cells near walls cost extra, so the first route to reach a cell may not be its cheapest.

A* is faster for one route, but it answers one start at a time. A flow field is computed once per target and shared by everyone heading there, and a person who gets pushed off course just reads the direction at their new cell, with nothing to re-plan. The cost is memory: about 6 bytes per cell per target, kept for every booth and table in use.

## How it works

1. Set every cell's cost to infinity and the target cells to 0. Put the targets in the heap.
2. Take the cell with the lowest cost out of the heap.
3. If the popped cost differs from the cell's recorded cost, this entry is out of date. Skip it.
4. For each legal neighbour, add the step length multiplied by one plus the wall penalty of that neighbour. If the total beats the neighbour's recorded cost, record it and push the neighbour.
5. Repeat until the heap is empty.
6. Give each cell a direction by following the lowest-cost neighbours four cells ahead and pointing at that cell, which smooths the zigzag of grid moves.

Step costs are never negative, so nothing found later can beat the lowest entry in the heap. That is why a cell's cost is final when its current entry is popped.

## One-way doors in a backward search

The search runs from the target outward, so reaching `next` from `current` means a person walks from `next` into `current`. A route must not step from open floor into a forbidden door cell, but someone already standing in one must be able to leave. So a blocked cell can receive a cost from open floor, and it passes cost on only to other blocked cells.

## Terms

Flow field: a table giving each cell's cost and walking direction toward one target. Frontier: the cells discovered but not yet finalised, held in the heap. Binary min-heap: an array arranged as a tree where each parent is no larger than its children, giving the smallest item in log time. Stale entry: an older heap entry for a cell that has since found a cheaper route.

## Pitfalls

The costs include wall penalties, so they are not metres. Near walls a cost of 1 can be well under a metre of walking.

Forgetting the corner rule lets a diagonal squeeze between two obstacles that touch only at their corners. A diagonal needs both side cells open.

## Further reading

E. W. Dijkstra, "A note on two problems in connexion with graphs", Numerische Mathematik 1 (1959): https://doi.org/10.1007/BF01386390

A. Treuille, S. Cooper, Z. Popovic, "Continuum crowds", ACM Transactions on Graphics 25(3) (2006): https://doi.org/10.1145/1141911.1142008
