# Mean-Intensity-Fluorescence-Macro-for-Immunofluorescence-Images-in-Fiji-Isabelle-Bergman-
This is a custom macro code for quantification of mean intensity fluorescence of immunofluorescence images in Fiji/Image J. 

It is designed to work with both:
- **RGB composites** where split-channel windows are labeled like `...(green)` / `...(blue)`, and
- **Hyperstacks** where split-channel windows are labeled like `C2-...` (green) and `C3-...` (blue).

---

## What it does

For each `.tif` / `.tiff` image in a selected folder, the macro:

1. **Opens the image**
2. **Splits channels** (`Image ▸ Color ▸ Split Channels`)
3. Identifies the **green** and **blue** channel images by title patterns:
   - Green: `C2-...`, `Ch2-...`, or `...(green)`
   - Blue:  `C3-...`, `Ch3-...`, or `...(blue)`
4. For each channel independently:
   - Computes a **background intensity estimate** as the **p-th percentile** of the image histogram (default `p = 5`)
   - Generates a **threshold-based ROI** (default threshold method: `Default`, configurable)
   - Measures **Mean intensity** on the original intensities within the ROI
   - Calculates **background-corrected mean** = `Mean(raw) – Background(pth percentile)` (floored at 0)
5. Writes results to a CSV with one row per input image

Outputs include both **raw** and **background-corrected** MFI for green and blue channels.

---

## Output

A CSV file (default: `Desktop/MFI_Results.csv`) with columns:

- `Filename`
- `Green Mean (raw)`
- `Blue Mean (raw)`
- `BG P{p} (Green)` — background estimate from the p-th percentile of green histogram
- `BG P{p} (Blue)` — background estimate from the p-th percentile of blue histogram
- `Green Mean (corr)` — background-corrected mean (floored at 0)
- `Blue Mean (corr)` — background-corrected mean (floored at 0)

If a channel is not detected, values are reported as `N/A`.

---

## Background subtraction method

Background is estimated as the **p-th percentile** of the pixel intensity distribution from a **256-bin histogram** (default `p = 5`). This approach is intended to be robust to sparse bright signal by using a low-end intensity estimate rather than mean/min.

---

## ROI detection and measurement strategy (robust behavior)

ROI detection is performed per channel using automated thresholding:

1. **Primary attempt (direct selection):**
   - Applies `setAutoThreshold("<method> dark")`
   - Attempts `Create Selection`
   - If a valid selection exists, measures mean intensity within that ROI

2. **Fallback method (binary mask selection):**
   - Duplicates the channel image to a temporary mask
   - Converts the duplicate to binary using `Make Binary... method=<method> background=Dark`
   - Creates a selection from the mask
   - Restores that selection onto the original image
   - Measures mean intensity (ROI if available; otherwise full image)

This two-step design reduces failures due to threshold/selection edge cases and ensures measurement proceeds even when ROI creation is not possible.

---

## Requirements

- **Fiji** (recommended) or **ImageJ** with macro support
- Images must be `.tif` or `.tiff`
- Channels should be interpretable after `Split Channels` such that green and blue can be identified by one of:
  - Hyperstack naming: `C2-` / `C3-` (or `Ch2-` / `Ch3-`)
  - RGB naming: `...(green)` / `...(blue)`

---

## How to run

### Interactive (within Fiji)
1. Open Fiji
2. `Plugins ▸ Macros ▸ Run...`
3. Select `Mean_Intensity_Fluorescence.ijm`
4. When prompted, choose the folder containing your `.tif/.tiff` images
5. The macro writes results to the default output path unless specified, which will appear as an MFI results folder on desktop 

### Scripted call (recommended for reproducibility)
Example call (as implemented in the macro header):

```text
run("script:Mean_Intensity_Fluorescence.ijm",
    "choose=[C:/path/to/folder/] out=[C:/path/MFI_Results.csv] p=5 thresh=[Otsu]");
