# DO NOT USE

This code is still in `BETA` and will **likely not work** when used. This is
just a side project I'm doing because I hate `FetchContent` and `ExternalProject`.

### Known Issues

 - **Install step** is now extremely **slow**, as it requires the library to be
   *configured* and *built*.

# CMake GetProject

`get_project()` function, **downloads** and **adds as a sub directory**
(*can be disabled*) an external project. The download is performed at
**configuration** time. Does **not rely** on `FetchContent` or `ExternalProject`.

The **default** directory where GetProject puts the libraries in `${CMAKE_HOME_DIRECTORY}/libs`.
If the `GET_PROJECT_OUTPUT_DIR` is set **before** including `GetProject.cmake`,
the user defined directory will be used.

The output will be placed in `${GET_PROJECT_OUTPUT_DIR}/${LIBRARY_NAME}`. `LIBRARY_NAME` will
be obtained through the `GIT_REPOSITORY` if not provided.

```cmake
get_project(
        TARGET                  # The target that depends on the library
        DOWNLOAD_ONLY           # If ON the library won't be added as a sub directory
        INSTALL_ENABLED         # If the install target needs to be built
        URL                     # Library URL
        LIBRARY_NAME            # Library name
        GIT_REPOSITORY          # Library git repository
        BRANCH                  # Library git branch
        KEEP_UPDATED            # If the library should be kept updated
        VERSION                 # A valid tag or LATEST for the latest release
        OPTIONS                 # Options that will be defined before adding the sub directory.
)
```

Setting `INSTALL_ENABLED` to true will cause the script to **configure**, **build**
and then **install** the library. This will be done at **configure time**.

## Examples

**Downloads** the project from a **URL** and **builds** and **installs** it.
The library will be placed in `${DIRECTORY}/${LIBRARY_NAME}`.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        INSTALL_ENABLED ON
        URL "https://github.com/torvalds/linux/archive/refs/tags/v6.12.zip"
        LIBRARY_NAME "linux-kernel"
        OPTIONS
                CMAKE_VERBOSE_MAKEFILE=ON
)
```

**Downloads** the library from a **git repository** and a **branch** keeping
the library **updated** but without performing the install step.

```cmake
get_project(
        DOWNLOAD_ONLY ON
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        BRANCH "master"
        KEEP_UPDATED ON
)
```

**Download** and **build** the library from a **git repository** and a **version**.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION "v6.3-rc1"
)
```

**Download** and **build** the **latest** version of the library from a **git repository**.

```cmake
get_project(
        TARGET ${PROJECT_NAME}
        GIT_REPOSITORY "https://github.com/torvalds/linux.git"
        VERSION LATEST
)
```