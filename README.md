# DO NOT USE

This code is still in `BETA` and will **likely not work** when used. This is just a
side project I'm pursuing thanks to the deep hate I feel against `FetchContent`
and `ExternalProject`.

### Known Issues

 - Requires the libraries to have been built **before** if they need to be added with
   `target_link_libraries` as the libraries are created at **build time**.<br>
   **Solution**: use `add_subdirectory()`, the **problem** is now performing the
   `install` step.

# CMake GetProject

`get_project()` function, **downloads** and **configures** (*can be disabled*) an
external project. The download is performed at **configuration** time. Does **not
rely** on `FetchContent` or `ExternalProject`.

The output will be placed in `${DIRECTORY}/${LIBRARY_NAME}`. `LIBRARY_NAME` will
be obtained through the `GIT_REPOSITORY` if not provided.

```cmake
get_project(
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

**Downloads** the project from a **URL** and **builds** and **installs** it.
The library will be placed in `${DIRECTORY}/${LIBRARY_NAME}`.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        INSTALL_ENABLED ON
        URL "https://github.com/torvalds/linux/archive/refs/tags/v6.12.zip"
        LIBRARY_NAME "linux-kernel"
        BUILD_ARGS
                -DCMAKE_VERBOSE_MAKEFILE=ON
)
```

**Downloads** the library from a **git repository** and a **branch** keeping
the library **updated** but without performing the install step.

```cmake
get_project(
        DOWNLOAD_ONLY ON
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        BRANCH "master"
        KEEP_UPDATED ON
)
```

**Download** and **build** the library from a **git repository** and a **version**.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION "v6.3-rc1"
)
```

**Download** and **build** the **latest** version of the library from a **git repository**.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        DIRECTORY "./libs"
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION LATEST
)
```