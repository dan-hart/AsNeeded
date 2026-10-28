# As Needed 1.2.0 screenshots

Six English iPhone screenshots, ordered for the App Store carousel. Each is 1320 × 2868 pixels, using the listing's existing yellow background (#F1D89C), dark copy, and a silver iPhone frame.

1. Next saved dose window
2. Optional next-dose availability notification (actual local notification)
3. Optional interval and rolling 24-hour quantity fields
4. Structured dose reflections in History
5. Trends and refill estimates
6. Quick Log confirmation and Undo

`iphone/` contains upload images. `raw/iphone/` preserves original app captures. `screenshots.json` records copy, provenance, and image hashes. `review/index.html` provides a visual review. `preview.png` is a contact sheet, not an upload asset.

Captured on an isolated iPhone 17 Pro Max simulator running iOS 26.5, using fictional medication/history data. The Debug app reports build 306: private-question removal was compiled before the build-number increment for the equivalent 307 release archive. No UI elements were fabricated. The simulator status bar was standardized to 9:41. The notification capture used a temporary short interval to trigger a real local notification; other screenshots use ordinary illustrative intervals. These values are examples, not medication instructions.

Framed with `asc screenshots frame` and Koubou 0.20.0. The installed CLI's current help takes precedence over older skill examples. Local capture/framing automation is experimental. All six images passed `asc screenshots validate --device-type IPHONE_69` with zero errors or warnings; the current CLI maps this to Apple's APP_IPHONE_67 API display type.

To reframe, run the following for each entry in `screenshots.json` with its raw path, title, subtitle, and output path:

```sh
asc screenshots frame --input raw/iphone/01-next-dose.png \
  --device iphone-17-pro-max --frame-color silver \
  --bg-color '#F1D89C' --title-color '#222126' --subtitle-color '#514936' \
  --title 'A little less clock math.' \
  --subtitle 'See your next saved dose window.' \
  --output-path iphone/01-next-dose.png
```

The new assets have not been uploaded. Existing iPad and watch listing screenshots are unchanged.
