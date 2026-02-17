// FIJI macro: Mean fluorescence (Green + Blue) with robust ROI detection and 5th-percentile background subtraction
// Works for RGB composites ("... (green)/(blue)") and hyperstacks ("C2-/C3-").
// Example call:
// run("script:Mean_Intensity_Fluorescence.ijm",
//     "choose=[C:/path/to/folder/] out=[C:/path/MFI_Results.csv] p=5 thresh=[Otsu]");

macro "Mean Fluorescence Intensity Batch" {

    // ---------- CONFIG ----------
    bgPercentile = 5.0;                 // small-percentile background (now 5%)
    thresholdMethod = "Default";        // e.g., "Otsu" or "Default"
    decimals = 3;                       // number of decimals in results
    // ----------------------------

    // ---- Parse optional arguments ----
    args = getArgument();
    inputDir   = parseOpt(args, "choose");
    outputPath = parseOpt(args, "out");
    pArg = parseOpt(args, "p");      if (pArg != "") bgPercentile = parseFloat(pArg);
    tArg = parseOpt(args, "thresh"); if (tArg != "") thresholdMethod = tArg;

    // ---- Resolve input directory ----
    if (inputDir == "" || inputDir == 0) {
        inputDir = getDirectory("Choose the folder with images");
        if (inputDir == "" || inputDir == 0) exit("No folder selected.");
    }
    if (!endsWith(inputDir,"/") && !endsWith(inputDir,"\\")) inputDir = inputDir + File.separator;

    // ---- Resolve output path ----
    if (outputPath == "" || outputPath == 0) {
        home = getDirectory("home");
        outputPath = home + "Desktop" + File.separator + "MFI_Results.csv";
    }

    // Prepare output file & measurement options
    outputFile = File.open(outputPath);
    print(outputFile, "Filename,Green Mean (raw),Blue Mean (raw),BG P"+bgPercentile+" (Green),BG P"+bgPercentile+" (Blue),Green Mean (corr),Blue Mean (corr)");
    run("Set Measurements...", "mean area min redirect=None decimal="+decimals);

    // Process all .tif/.tiff files
    list = getFileList(inputDir);
    for (i=0; i<list.length; i++) {
        name = list[i];
        if (!(endsWith(name, ".tif") || endsWith(name, ".tiff"))) continue;

        open(inputDir + name);
        filename = name;

        run("Split Channels");

        // Detect green & blue windows (RGB and hyperstack naming)
        greenWin = ""; blueWin = "";
        n = nImages;
        for (ii=1; ii<=n; ii++) {
            selectImage(ii);
            wt  = getTitle();
            wtl = toLowerCase(wt);
            if (startsWith(wtl,"c2-") || startsWith(wtl,"ch2-") || indexOf(wtl,"(green")!=-1) greenWin = wt;
            if (startsWith(wtl,"c3-") || startsWith(wtl,"ch3-") || indexOf(wtl,"(blue") !=-1) blueWin  = wt;
        }

        // ----- GREEN -----
        greenMeanRaw = "N/A"; greenBG = "N/A"; greenMeanCorr = "N/A";
        if (greenWin != "") {
            selectWindow(greenWin);
            greenBG = percentileBackground(bgPercentile);
            greenMeanRaw = robustMeanWithSelection(thresholdMethod);
            greenMeanCorr = greenMeanRaw - greenBG; if (greenMeanCorr < 0) greenMeanCorr = 0;
            close();
        }

        // ----- BLUE -----
        blueMeanRaw = "N/A"; blueBG = "N/A"; blueMeanCorr = "N/A";
        if (blueWin != "") {
            selectWindow(blueWin);
            blueBG = percentileBackground(bgPercentile);
            blueMeanRaw = robustMeanWithSelection(thresholdMethod);
            blueMeanCorr = blueMeanRaw - blueBG; if (blueMeanCorr < 0) blueMeanCorr = 0;
            close();
        }

        // Close remaining open windows
        while (nImages > 0) { selectImage(nImages); close(); }

        run("Clear Results");

        // Save row
        print(outputFile,
            filename + "," +
            greenMeanRaw + "," + blueMeanRaw + "," +
            greenBG + "," + blueBG + "," +
            greenMeanCorr + "," + blueMeanCorr
        );
    }

    File.close(outputFile);
    print("Batch analysis complete. Saved: " + outputPath);
}


// ----------------- Helper Functions -----------------

// Parse key=value or key=[value] from arguments
function parseOpt(s, key) {
    if (s == "") return "";
    ks = key + "=";
    idx = indexOf(s, ks);
    if (idx == -1) return "";
    start = idx + lengthOf(ks);
    rest = substring(s, start);
    if (startsWith(rest, "[")) {
        rest = substring(rest, 1);
        end = indexOf(rest, "]");
        if (end == -1) return rest;
        return substring(rest, 0, end);
    } else {
        end = indexOf(rest, " ");
        if (end == -1) return rest;
        return substring(rest, 0, end);
    }
}

// Compute percentile background from channel histogram
function percentileBackground(pct) {
    nBins = 256;
    getHistogram(values, counts, nBins);
    total = 0; for (k=0; k<nBins; k++) total += counts[k];
    target = (pct/100.0)*total;
    acc=0; idx=0;
    while (idx<nBins && acc<target) { acc+=counts[idx]; idx++; }
    if (idx<=0) idx=1;
    return values[idx-1];
}

// Create a robust thresholded selection and measure mean on original intensities
function robustMeanWithSelection(methodBase) {
    // Attempt direct threshold first
    r0 = nResults;
    setAutoThreshold(methodBase + " dark");
    getThreshold(lo, hi);
    if (lo!=-1 && hi!=-1) {
        run("Create Selection");
        if (selectionType()!=-1) {
            run("Measure");
            return getResult("Mean", r0);
        }
    }

    // Fallback: build a temporary mask, copy selection to original
    origTitle = getTitle();
    run("Duplicate...", "title=__tmpMask__");
    selectWindow("__tmpMask__");
    run("Make Binary...", "method="+methodBase+" background=Dark");
    run("Create Selection");
    hasSel = (selectionType()!=-1);
    selectWindow(origTitle);
    if (hasSel) run("Restore Selection");
    close("__tmpMask__");

    // Measure (ROI or full image if none)
    r0 = nResults;
    run("Measure");
    return getResult("Mean", r0);
}

