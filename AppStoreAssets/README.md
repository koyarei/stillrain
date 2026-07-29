# StillRain App Store Artwork

This folder contains a three-image launch concept built around StillRain's
existing midnight-navy and still-rain visual language.

## Deliverables

- `portrait/`: 1024 x 1536 high-resolution campaign masters.
- `watch-416x496/`: RGB PNG exports at the accepted Apple Watch Series 10/11
  App Store screenshot size.
- `watch-422x514/`: RGB PNG exports at the accepted Apple Watch Ultra 3 App
  Store screenshot size.
- `raw/`: text-free image-generation outputs for future revisions or localization.
- `build_assets.py`: deterministic typography, crop, and export script.

The generated product scenes are concept marketing artwork. Before submission,
compare the depicted watch behavior with the shipping build and replace any
screen treatment that does not match the final app exactly.

## Generation prompts

All three images used the existing `source-app-icon.png` as a brand reference.
The built-in image generator created text-free, photorealistic portrait masters
with deep navy negative space and realistic Apple Watch usage:

1. A wrist in a softly blurred tense social setting, with a discreet dark app
   surface and one pale rain ripple.
2. A dark watch floating over calm midnight water, with restrained concentric
   ripples suggesting a tactile pulse.
3. A fingertip approaching the StillRain complication on a dark watch face,
   emphasizing one-tap access.

Each prompt explicitly excluded text, medical or heart-rate UI, microphones,
timers, charts, spiritual symbols, dramatic distress, and watermarks.

## Rebuild

Install Pillow, then run:

```sh
python3 AppStoreAssets/build_assets.py
```
