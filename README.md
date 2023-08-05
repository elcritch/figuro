
# Figuro

An (experimental) UI toolkit for Nim. It's based on Fidget, though will likely begin to diverge significantly.

The core idea is to split it into two main pieces:

1. Widget / UI Application
2. Rendering Engine

## Widget and Application Layer

The UI Application side will draw UI Nodes using widgets. Widgets will comprise of objects with common set of methods. Each widget will then use a Fidget-like API to draw themselves.

All of the widgets will share the same UI Node roots, similar to Fidget. However, events will be handled using the widget methods, similar to traditional UI toolkits. Ideally this gives us the best of both worlds: immediate mode like drawing, with traditional event systems. This should also resolve the ordering issues with Fidget / Fidgetty when dealing with overlapping widgets.

## Render Engine

Once the UI Application has finished drawing, it will "serialize" the UI Nodes into a flattened list of Render Nodes. These Render Nodes are designed to be fast to copy by reducing allocations.

This will enable the render enginer to run on in a shared library while the widget / application layer runs in a NimScript.

## Goal

Massive profits and world domination of course. ;) Failing that the ability to write cool UI apps easily, in pure Nim.
