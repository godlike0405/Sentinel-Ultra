GeoLibre needs two advanced imagery workflows that run locally in its web and
desktop clients: object detection and automatic “segment everything.” Complete
the processing support and client integration for both workflows. They must
work in ordinary browser environments without the Python sidecar, cross-origin
isolation, or `SharedArrayBuffer`.

Both workflows must appear as advanced Processing actions and remain hidden by
the simpler interface profile. They should load independently in the browser
application. Provide clear English copy for selecting inputs, configuring a
run, showing progress or results, and reporting errors.

## Object detection

Users can run an Ultralytics YOLO ONNX model against a GeoTIFF, using either a
built-in downloadable choice or their own model. Provide at least two distinct
built-in detection models over HTTPS.

Support standard YOLOv5 and YOLOv8/v11 detection exports. All predictions that
meet the requested threshold must be returned with the right class, confidence,
and source-image box. Malformed output must fail clearly. Overlapping results
from the same class should be reduced without merging different classes or
unrelated objects.

The workflow must handle single-band and color rasters across the common value
ranges used by normalized imagery, integer imagery, and floating-point
reflectance. NoData and rasters without usable samples must not make the result
numerically invalid. Returned boxes must be finite, bounded, and expressed in
source-raster pixels.

Expose `detectObjects` from the top-level `@geolibre/processing` API. It accepts
the raster, ONNX model bytes, and optional `inputSize`, `confidenceThreshold`,
and `iouThreshold` settings. `inputSize` must be an integer from 32 through
4096; both thresholds must be finite values in `[0, 1]`; invalid settings must
be rejected before inference. Each returned detection exposes `bbox`,
`classIndex`, and `score`.

## Automatic segmentation

Add a browser ONNX workflow that automatically segments a raster with an
encoder and decoder model pair. Ship distinct HTTPS model assets for the two
parts. Users must be able to configure the sampling grid, observe progress,
cancel a run, and receive useful model errors.

Expose `segmentEverything` from the top-level processing API. It accepts the
raster, encoder bytes, decoder bytes, and options including `pointsPerSide`,
`onProgress`, and `signal`. `pointsPerSide` must be an integer from 2 through 48
and must be rejected before model inference when invalid. Each result exposes a
`polygon`, `score`, and positive `area`. Polygons must be closed, finite,
bounded, and expressed in source-raster pixels; progress must reach completion,
and cancellation must stop the run.

## Runtime and compatibility

Use a reproducibly pinned browser inference runtime shared by both workflows.
The processing package must still import when that runtime cannot be loaded;
inference is the point at which it becomes necessary. Export the exact installed
runtime version as `ORT_VERSION`. The top-level processing API and complete
desktop application must continue to bundle for a normal browser target. The
existing map editor plugin must continue to expose its registration identifier.
