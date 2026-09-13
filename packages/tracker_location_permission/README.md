# tracker_location_permission

The Android half of the tracker apps' location permission flow: `ACCESS_BACKGROUND_LOCATION` and `ACCESS_FINE_LOCATION` requested **one at a time** — Android 11+ ignores a request that bundles background with foreground, and the `location` plugin makes exactly that request. Android only; on iOS every call resolves to success and the `location` plugin's own flow applies.
