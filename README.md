This code is still in `BETA` and **may not work** when used. This is
just a side project that exists just because I hate `FetchContent` and `ExternalProject`.

# CMake GetProject

`get_project()` function, **downloads** and **adds as a sub directory**
(*can be disabled*) an external library. The download is performed at
**configuration** time. Does **not rely** on `FetchContent` or
`ExternalProject`.

The **default** directory where GetProject puts the libraries in
`${CMAKE_HOME_DIRECTORY}/libs`. If the `GET_PROJECT_OUTPUT_DIR` is set 
**before** including `GetProject.cmake`, the user defined directory will be
used.

The output will be placed in `${GET_PROJECT_OUTPUT_DIR}/${LIBRARY_NAME}`. 
`LIBRARY_NAME` will be obtained through the `GIT_REPOSITORY` if not provided.

```cmake
get_project(
        URL                    # Library URL
        GIT_REPOSITORY         # Library git repository
        FILE                   # If ARGS_URL downloads a single file
        LIBRARY_NAME           # Library name (can be inferred from git repo)
        INSTALL_ENABLED        # If the library needs to be installed (requires extra build)
        DOWNLOAD_ONLY          # If ON the library won't be added as a sub directory
        BRANCH                 # Library git branch
        KEEP_UPDATED           # If the library should be kept updated
        VERSION                # A valid tag or LATEST for the latest release
        OPTIONS                # Options that will be defined before adding the sub directory.
)
```

Setting `INSTALL_ENABLED` to true will cause the script to **configure**,
**build** and then **install** the library. This will be done at **configure
time**.

## Usage

The `URL`, `GIT_REPOSITORY` arguments are **mutually exclusive**.

The `BRANCH` arguments may be used with the `KEEP_UPDATED` option, `VERSION` is
used when **no branch** is provided. 