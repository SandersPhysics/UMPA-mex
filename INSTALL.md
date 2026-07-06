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

Windows users should install Microsoft Visual Studio Build Tools with the **Desktop development with C++** workload:

https://visualstudio.microsoft.com/downloads/

macOS users should install Apple Xcode Command Line Tools:

```bash
xcode-select --install
```

Apple developer tools are also available here:

https://developer.apple.com/xcode/resources/



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


