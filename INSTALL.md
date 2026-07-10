# Installation

This project can run in either pure MATLAB mode or faster C++/MEX mode.

Pure MATLAB mode does not require a C++ compiler.
C++/MEX mode requires a MATLAB-supported C++ compiler.

## Requirements

- MATLAB
- Image Processing Toolbox
- Project folder containing:
  - `runUMPA.m`
  - `MEXbuilder.m`
  - `script functions/`



## C++/MEX mode

First check whether MATLAB already has a C++ compiler configured:

```matlab
mex -setup cpp
```

If MATLAB does not find a compiler, install one for your operating system.

Linux users can install the standard build tools:

```bash
sudo apt update
sudo apt install build-essential
```

Windows users should install the MATLAB-supported MinGW compiler through MATLAB:

1. Open MATLAB.
2. Go to the **Home** tab.
3. In the **Environment** section, select **Add-Ons**.
4. Search for **MATLAB Support for MinGW-w64 C/C++/Fortran Compiler**.
5. Install the add-on.
6. Restart MATLAB.

After installation, run:

```matlab
mex -setup cpp
```

## macOS

The macOS MEX build requires Apple's C++ development tools. The required component is the **Xcode Command Line Tools**, which provides the Apple Clang++ compiler, macOS SDK, linker, and related build utilities.

### Install Xcode

Open the **Mac App Store**, search for **Xcode** by Apple, and install it.

The full Xcode download is large, but it provides the most straightforward setup for MATLAB MEX compilation.

After installation:

1. Open Xcode once.
2. Accept the license agreement.
3. Allow Xcode to install any requested additional components.
4. Open **Xcode → Settings → Locations**.
5. Under **Command Line Tools**, select the installed Xcode version.

If Xcode is unavailable through the App Store, Apple also provides standalone **Command Line Tools for Xcode** installer packages through Apple Developer Downloads. An Apple Account is required, but paid Apple Developer Program membership is not required.

### macOS compatibility

The current macOS OpenMP build has been validated on:

- Apple Silicon
- MATLAB R2026a Update 1
- `maca64`

The builder is not hardcoded to R2026a. It derives its paths from the active MATLAB installation and architecture.

Other MATLAB releases may work when they include the expected bundled OpenMP header and runtime. If those files are unavailable or stored differently, `MEXbuilder` will report the missing path.

Intel Mac support has not yet been validated. MATLAB R2025b is the final MATLAB release available for Intel Macs.



After installing the compiler, restart MATLAB and run:

```matlab
mex -setup cpp
```

## Build MEX files

From the project root folder in MATLAB, run:

```matlab
MEXbuilder
```

This builds the compiled functions used by the fast path:

- `build_test_mex`
- `umpa_core_mex`
- `image_cleanup_mex`


