# get_library

Some utility functions for CMake. All functions use the `cmake_parse_arguments()` function.
To call a function the parameter name must be specified.

```cmake
get_library(
        TARGET                  # The target that depends on the library
        DOWNLOAD_ONLY           # If ON does blocks configuration
        DIRECTORY               # The directory the library will be placed in
        INSTALL_ENABLED         # If the install target needs to be built
        URL                     # Library URL
        LIBRARY_NAME            # Library name
        GIT_REPOSITORY          # Library git repository
        BRANCH                  # Library git branch
        KEEP_UPDATED            # If the library should be kept updated
        VERSION                 # A valid tag or LATEST for the latest release
        BUILD_ARGS              # Build arguments passed to the configure command.
)
```

## Examples

**Download** and **build** the library from a URL with the **install** step.
The library will be placed in `${DIRECTORY}/${LIBRARY_NAME}`.

```cmake
get_library(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        INSTALL_ENABLED ON
        URL "https://github.com/torvalds/linux/archive/refs/tags/v6.12.zip"
        LIBRARY_NAME "linux-kernel"
        BUILD_ARGS
                -DCMAKE_VERBOSE_MAKEFILE=ON
)
```

**Download** the library from a **git repository** and a **branch** keeping
the library **updated** but without performing the install step.
The library will be placed in `${DIRECTORY}/<repo_name>`.

```cmake
get_library(
        DOWNLOAD_ONLY ON
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        BRANCH "master"
        KEEP_UPDATED ON
)
```

**Download** and **build** the library from a **git repository** and a **version**.
The library will be placed in `${DIRECTORY}/<repo_name>`.

```cmake
get_library(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION "v6.3-rc1"
)
```

**Download** and **build** the **latest** version of the library from a **git repository**.
The library will be placed in `${DIRECTORY}/<repo_name>`.

```cmake
get_library(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION LATEST
)
```