# UMPA-mex

UMPA-mex is a MATLAB implementation of Unified Modulated Pattern Analysis with an optional faster C++/MEX backend.

The main driver is `runUMPA.m`.

## Project structure

Expected project layout:

- `runUMPA.m`
- `MEXbuilder.m`
- `script functions/`
- `Sample_total/`
- `Ref_total/`
- `Calibration images/`

The image data folders are not committed to Git. Users should place their own input images in the expected folders before running the code.

## Running the code

Open MATLAB from the project root folder and run:

```matlab
runUMPA
```

The main reconstruction options are set near the top of `runUMPA.m`.

Important settings include:

- `umpa_core`
- `filter_core`
- `umpa_mode`
- `umpa_w_half`
- `umpa_w_shft`
- `bias_correct_shifts`
- `bias_correction_mode`

## Reconstruction cores

Pure MATLAB mode:

```matlab
umpa_core = 'original';
```

C++/MEX mode:

```matlab
umpa_core = 'mex';
```

The MEX version requires compiled MEX files. See `INSTALL.md`.

## Reconstruction modes

Dark-field mode:

```matlab
umpa_mode = 'DF';
```

DPC-only mode:

```matlab
umpa_mode = 'DPC';
```

`DF` reconstructs attenuation, dark-field, and DPC shifts.

`DPC` reconstructs attenuation and DPC shifts with dark-field disabled.

## Current notes

The current MEX path supports:

```matlab
umpa_w_shft = 1;
```

Larger MEX shift windows are not part of the current validated release.

Compiled MEX files are generated locally and should not be committed to Git.

## Installation

See `INSTALL.md`.

## License

This project is released under the MIT License. See `LICENSE`.
