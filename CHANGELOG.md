# Changelog

## Initial Git release

This release ports the lab-drive UMPA workflow into a cleaner Git-ready project while preserving both the original MATLAB reconstruction path and the faster C++/MEX path.

### Added

- Added optional C++/MEX UMPA backend through `UMPA_mex.m` and `umpa_core_mex.cpp`.
- Added optional C++/MEX image cleanup backend through `cleanup_image_stack.m` and `image_cleanup_mex.cpp`.
- Added `MEXbuilder.m` for building the current compiled targets:
  - `build_test_mex`
  - `umpa_core_mex`
  - `image_cleanup_mex`
- Added sandbox controls near the top of `runUMPA.m` for:
  - `umpa_core`
  - `filter_core`
  - `umpa_mode`
  - `umpa_w_half`
  - `umpa_w_shft`
  - `bias_correct_shifts`
  - `bias_correction_mode`
- Added support for selecting between the original MATLAB UMPA path and the C++/MEX fast path.
- Added support for selecting between MATLAB image cleanup and C++/MEX image cleanup.
- Added DPC-only mode through `umpa_mode = 'DPC'`.
- Added mode normalization so `DPC`, `nodf`, and `no_df` are treated as no-dark-field reconstruction modes.
- Added optional reference-vs-reference shift-bias correction.
- Added `apply_umpa_bias_correction.m`.
- Added `plot_umpa_bias_shifts.m` for inspecting raw shifts and reference-bias shifts.
- Added fixed display limits for bias shift inspection plots.

### Changed

- Renamed the main compiled UMPA core to `umpa_core_mex`.
- Renamed the compiled image cleanup core to `image_cleanup_mex`.
- Renamed the MATLAB cleanup wrapper to `cleanup_image_stack.m`.
- Updated `runUMPA.m` to use explicit sandbox settings instead of editing deeper function calls.
- Updated `runUMPA.m` so `struct.mode` is set from `umpa_mode`.
- Updated the original MATLAB UMPA path to use explicit mode input instead of hidden `varargin` behavior.
- Updated the original MATLAB UMPA path to support both `DF` and `DPC` modes.
- Updated the MEX UMPA wrapper to pass mode information into the C++ core.
- Updated the C++ UMPA core to branch between dark-field and no-dark-field reconstruction.
- Updated the no-dark-field path to use a stable placeholder dark-field channel instead of avoidable NaN-producing expressions.
- Embedded the 3x3 subpixel minimum fit inside the main C++ UMPA core.
- Replaced the older generic matrix-style subpixel helper workflow with fixed 3x3 direct quadratic-fit logic.
- Simplified the live MEX build list to only the active compiled targets.
- Moved bias correction and bias plotting helpers into the main `script functions/` path.
- Updated `MEXbuilder.m` to use `script functions/mex_source/` as the canonical MEX source folder.
- Updated `MEXbuilder.m` to build compiled MEX binaries into `script functions/mex_bin/<platform>/` so the outputs are found by the existing `script functions` path setup.
- Updated Windows installation instructions to recommend installing the MATLAB-supported MinGW compiler through MATLAB Add-Ons.
- Updated `numelements.m` to count only supported image files instead of all non-hidden files.
- Updated `shiftloader.m` to load only supported image files and ignore non-image files such as `README.md`, `Thumbs.db`, `desktop.ini`, and hidden system files.
- Updated image loading to sort files by name before loading for more consistent sample/reference ordering.

### Removed

- Removed `w_step` from the live driver/API.
- Removed `struct.corrparam.step`.
- Removed `w_step` from UMPA function signatures and calls.
- Removed hidden/default `w_step` behavior.
- Removed old standalone subpixel MEX helpers from the live build path:
  - `subpix3x3_mex`
  - `minsubpix3x3_mex`
- Removed old compiled-core naming tied to `wshift1` and `df`.
- Removed old cleanup naming tied to `filter_cleanup_oldlogic_mex` and `singularityswitch_mex` from the MEX path.
- Removed duplicate MEX source folder from the Git project structure.
- Removed or excluded MATLAB autosaves, compiled MEX binaries, data files, output files, and other generated files from Git tracking.

### Fixed

- Fixed DPC/no-dark-field mode so it runs without the old dark-field-only guard.
- Fixed MEX path support for `w_half`.
- Fixed bias correction workflow so reference-vs-reference reconstruction can be run using the same selected UMPA core.
- Fixed bias plotting syntax issue in `plot_umpa_bias_shifts.m`.
- Fixed project cleanup so the default MEX run, sandbox settings, and bias correction run work in the minimal Git test folder.
- Fixed fresh-download MEX build failure caused by `MEXbuilder.m` looking for source files in the old root-level `mex_source/` folder.
- Fixed fresh-download MEX path behavior so compiled binaries are generated inside the project function tree.
- Fixed image count errors caused by placeholder files inside input image folders.
- Fixed fresh-download runs where `README.md` files in `Sample_total/`, `Ref_total/`, or `Calibration images/` could be counted as data files.
- Fixed potential sample/reference mismatch errors caused by non-image system files appearing in image folders.

### Current limitations

- The current C++/MEX UMPA path supports `umpa_w_shft = 1`.
- Generalized `w_shft > 1` support is pending.
- Edge-minimum behavior for larger shift windows is pending.
- Sample shifting is pending.
- GPU mode is not part of the current supported Git release.
- The experimental `shifted_lookup` bias correction mode is retained for comparison, but `same_pixel` is the cleaner theoretical default.

### Notes

- The original MATLAB implementation is still retained through `umpa_core = 'original'`.
- The C++/MEX backend is intended as a faster optional path, not a replacement for the MATLAB reference path.
- Compiled MEX binaries are generated locally and should not be committed to Git.
