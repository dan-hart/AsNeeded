# As Needed header and search artwork

Approved en-US artwork uploaded and assigned to App Store version 1.2.0 on October 29, 2026. Both placement records read back as ACTIVE; the underlying images remain PREPARE_FOR_SUBMISSION. They have not been submitted for review or published. Sanitized resource IDs are recorded in `manifest.json`.

| Placement | Export | Dimensions |
| --- | --- | --- |
| Product page header | `header.png` | 3840 × 1646 |
| Search results | `search-results.png` | 3840 × 2560 |

The background is **#F1D89C**, read directly from `AsNeeded/AppIcon.icon/icon.json`. The two pill layers are the original app icon artwork. All typography uses outlines from the bundled **Atkinson Hyperlegible Regular and Bold** fonts, avoiding any font substitution during export. License: `AsNeeded/Resources/Fonts/Licenses/AtkinsonHyperlegible-LICENSE.txt`.

The SVGs contain outlined glyphs and reference the original pill PNGs in `assets/`; keep that folder beside the SVGs. PNG exports are opaque RGB in sRGB. The revised header contains only the pills and wordmark on yellow, with no subtitle or decorative background shapes. A 64-pixel gap separates the pills and wordmark, increased from 23 pixels in the first subtitle-free revision.

Apple's [Photoshop header template](https://developer.apple.com/go/?id=photoshop-product-page-header-template), checked October 29, 2026, defines an **Art Safe Area of 1646 × 661 at (1097, 493)** within the 3840 × 1646 canvas. The revised branding's measured pixel bounds are **(1109, 598)–(2732, 1049)**: centered, fully inside that area, and using almost its entire width. Check the final placement in App Store Connect's Preview tool before publishing.

Recreate from the repository root with:

```sh
python3 Design/AppStoreConnect/1.2.0/creative-assets/render_assets.py
```

Add `--only header` to regenerate the header without touching the search image.

Rendering requires FontTools, librsvg's `rsvg-convert`, and ImageMagick's `magick`. These are artwork-authoring tools, not application build dependencies. No app code or screenshots are modified.

Sources: [Apple's creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) and [asset best practices](https://developer.apple.com/app-store/asset-best-practices/), checked October 29, 2026.
