# Nuclei segmentation and cell-type census: analysis notebooks

Notebooks for segmenting nuclei in SBF-SEM (3View) volumes of planaria, presenting each nucleus to human annotators for cell-type classification, and analyzing the resulting census. Used for the 20-15 irradiation series (homeostatic control, 4, 8 and 14 dpi) and the 48 hpa amputation dataset.

Location: `S:\micro\asa\stn\mel\20-15_Irradiation_Datasets\20210721_MER_IMARE-106746_20_15_1A_control\20-15-1A_after_crash\cjw\DeepLearn\`

## Pipeline order

| Step | Notebook / tool | Does |
|---|---|---|
| 1 | `Normalize.ipynb`, `NormalizeImages.ipynb` | Per-slice contrast normalization of the bin4 stacks |
| 2 | DeepFijiv2 
| 3 | `NucleiiFinder.ipynb` | Turns probability maps into labeled 3D nuclei (`Labels.tif`) |
| 4 | `Calculate_Volume_CenterOfMass.ipynb` | Volume and center of mass for every nucleus |
| 5 | `ParseOutNucleii.ipynb` | Crops each nucleus into its own mini-volume for annotation |
| 6 | `Classifier/` (Fiji: `Classify.ijm` + plugin; `Randomizer.ipynb`) | Presents mini-volumes to annotators and records labels as CSV |
| 7 | `ShowClasses.ipynb` (+ variants) | Merges annotations, maps labels back onto the volume, plots |
| 8 | `ShowClasses_Heterochromatin.ipynb`, `ClustersViewer.ipynb` | Heterochromatin and 3D shape analysis per cell type |

## Notebooks

### Normalize.ipynb
Contrast-normalizes stacks so that one trained model works across datasets despite beam-intensity drift. It contains two approaches:
- Matching an older training set's 5th/95th intensity percentiles to a new dataset's.
- The method used from then on: each slice is scaled so its 5th–95th percentile (measured inside a 400-px border) maps to 50–200 on an 8-bit scale.

Writes `<input>_normed.tif`.

### NormalizeImages.ipynb
The same per-slice percentile normalization, applied to the 48 hpa stack (`stitch_stack_ali_bin4.tif`). It ignores zero-valued padding when computing percentiles.

### NucleiiFinder.ipynb
Input: `Output.tif`, the U-Net output (raw + prediction channels).
1. Gaussian blur along Z on the mask channel.
2. Threshold at 128 (0.5 probability).
3. Label 3D connected components (`scipy.ndimage.label`).
4. Discard components under 50,000 voxels, then relabel.

Writes `Labels.tif` (uint16, one integer ID per nucleus), plus `Labels.npy`, `Counts.npy`, `Size_Filtered.npy` and `Filtered_Labels.npy`. Set `data` to the dataset folder you want to process.

### Calculate_Volume_CenterOfMass.ipynb
Loops over all datasets, reads each `Labels.tif`, and computes voxel volume and center of mass per nucleus. The center of mass is computed on a 4×-downsampled copy for speed, then scaled back up. Writes `Volume-CMs.csv`.

### ParseOutNucleii.ipynb
Uses `scipy.ndimage.find_objects` on `Labels.tif` to crop every nucleus. Choose the dataset with `current_dataset` (0 control, 1 4dpi, 2 8dpi, 3 14dpi, 4 48hpa). Output files are named `<ID>_<dataset>.tif`, with the ID zero-padded to 4 digits. Outputs:
- `Nucleii/`: bounding box padded by 40 px in XY and 5 slices in Z; 2 channels (raw EM, label image). The annotation lists point to copies of these crops, pooled from all datasets, in `Classifier/AllNucleii/` (48 hpa: `Classifier/AmputatedNucleii/`).
- `SingleMaskNucleii/`: the bounding box only, with a binary mask of just that nucleus.
- `SingleMaskNucleiiFullRes/`: full-resolution crops read from the OME-Zarr, CLAHE-equalized inside the nuclear mask. Input to the heterochromatin segmentation.
- `Classifier/AutoClassifier/Tiffs/`: fixed 256 × 256 × 64 windows, Z subsampled by 8. Made for an automated-classifier test.

### Classifier/ (Fiji) and Classifier/Randomizer.ipynb
- `Classify.ijm` reads a two-column CSV (`Type,File`, with Type initially `0`) and launches the *Classify Individual Files Others* plugin. The plugin shows each mini-volume in turn and writes the annotator's label back into the CSV.
- `Randomizer.ipynb` builds randomized file lists for annotation (for example, `Montaged_List.csv`, 500 random control nuclei for nucleolus counting) and tallies labels per dataset.

Annotation results are named `<ANNOTATOR>_<round>_<date>.csv`:
- `*_Split_*`: first pass. The pooled nuclei from all four datasets are divided among annotators with no overlap.
- `*_Others_*`: second pass. Nuclei left as Other/Doublet/Muscle/Neuronal are re-scored by a different annotator.
- `*_Amputated_List_*`: the 48 hpa round, with 448 homeostatic nuclei mixed in blind as a consistency check.

### Classify.ijm
- Cycles through files and calls the imagej plugin Classify Individual (github.com/jouyun/smc-plugins)


### ShowClasses.ipynb
The main analysis notebook.
- Loads every annotation CSV and applies the second-pass labels on top of the first pass.
- Joins the labels with nucleus volumes, centers of mass and nucleolus counts (from `../DeepLearn_Nucleoli/`).
- Paints the labels back into the volume as a napari labels layer.

It produces the cell-type fraction plots per dataset (`TypeFraction.html`), the annotator-consistency confusion matrices (`ConfusionMatrix_*.html`, `InconsistentClassifications*.csv`), nucleoli per cell type (`NucleoliByCellType.html`), and nearest-neighbor cell-type analysis. Several plotly figures are wired to napari, so clicking a point jumps the viewer to that nucleus.


### ClustersViewer.ipynb (also ClustersViewer.py)
A standalone viewer for the outputs of `ShowClasses_Heterochromatin`. It loads the raw volume, the classified labels and the per-type label layers into napari, attaching the statistics table as layer properties. It is meant for use with the napari-clusters-plotter plugin.

### CLAHE.ipynb, FalseNegatives.ipynb
Scratch notebooks. `CLAHE` tests histogram-equalization settings; `FalseNegatives` is empty.

## Key data files in this folder

| File | Contents |
|---|---|
| `Output.tif` | U-Net output for the control volume: raw + prediction channels |
| `Labels.tif` | Segmented nuclei; each nucleus has its own integer ID. Nucleus ID = label − 1 = the number in the mini-volume filename |
| `CentersMass.npy`, `Volumes.npy` | Per-nucleus center of mass and volume (voxels) |
| `Statistics.csv` | Merged per-nucleus table: type, volumes, heterochromatin, shape |
| `Classifier/*.csv` | Annotation lists and results (see above) |

## Running

- Environment: Python 3 with `napari`, `numpy`, `scipy`, `scikit-image`, `tifffile`, `opencv-python`, `pandas`, `plotly`, and `zarr` (for the full-resolution crops). Notebooks start with `%gui qt` for napari.
- Paths are hard-coded to `S:/micro/asa/stn/mel/20-15_Irradiation_Datasets/...`. Most notebooks define a `datas` list of dataset folders and select one with `current_index` / `current_dataset`.
- The notebooks were run interactively, cell by cell, and contain exploratory cells that are not part of the pipeline. Do not expect a top-to-bottom run to work without editing.
- Voxel size: the bin4 volumes are about 0.12 µm in XY and Z. Full-resolution XY is 4× finer (about 30 nm).
