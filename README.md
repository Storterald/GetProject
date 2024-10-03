# CMake Utilities Functions

Some utility functions for CMake. All functions use the `cmake_parse_arguments()` function. 
To call a function the parameter name must be specified.

## get_library.cmake

Requires the `git_utils.cmake` file.

- `download_file_from_url():` Fetches a file from a defined **URL**.<br>
```cmake
download_file_from_url(
        # The URL from where the file will be fetched.
        URL
        # The directory where the library directory will be created.
        DIRECTORY
        # The fetched file name.
        FILE_NAME

        # --------- Optional parameters ---------

        # The file hash.
        HASH
        # The file hash type.
        HASH_TYPE
)
```
- `download_from_url():` Fetches a library from the given **URL**.<br>
```cmake
download_from_url(
        # The URL from where the library will be fetched.
        URL
        # The directory where the library directory will be created.
        DIRECTORY
        # The library name, also the name of the directory that 
        # will be created inside the directory parameter.
        LIBRARY_NAME
)
```
- `build_from_url():` Fetches a library and builds it from the given **URL**. The library is required to have *CMakeLists.txt*.<br>
```cmake
build_from_url(
        # The target that depends on the library.
        TARGET
        # The URL from where the library will be fetched.
        URL
        # The directory where the library directory will be created.
        DIRECTORY
        # The library name, also the name of the directory that 
        # will be created inside the directory parameter.
        LIBRARY_NAME
        
        # --------- Optional parameters ---------

        # If the library has defined an install() function.
        INSTALL_ENABLED
        # Extra args to pass when building the library.
        BUILD_ARGS
)
```
- `download_file_from_branch():` Fetches a file from a GitHub repository. Requires the branch name.<br>
```cmake
download_file_from_branch(
        # The profile name hosting the git repository.
        PROFILE_NAME
        # The git repository name.
        REPOSITORY_NAME
        # The branch containing the file.
        BRANCH_NAME
        # The file path inside the repository.
        FILE_PATH
        # The directory where the library directory will be created.
        DIRECTORY
)
```
- `download_from_branch():` Fetches a library with the given branch. Uses **git**.<br>
```cmake
download_from_branch(
        # The profile name hosting the git repository.
        PROFILE_NAME
        # The git repository name.
        REPOSITORY_NAME
        # The branch containing the file.
        BRANCH_NAME
        # The directory where the library directory will be created.
        DIRECTORY

        # --------- Optional parameters ---------

        # When set to 'ON', if the library has already been cloned, a git
        # pull will be done.
        KEEP_UPDATED
)
```
- `download_latest_release():` Fetches the latest ***release*** of a library from GitHub. Uses **git**.<br>
```cmake
download_latest_release(
        # The profile name hosting the git repository.
        PROFILE_NAME
        # The git repository name.
        REPOSITORY_NAME
        # The directory where the library directory will be created.
        DIRECTORY
)
```
- `build_latest_release():` Fetches and builds the latest release of a library from GitHub. Uses **git**.
  The library is required to have a *CMakeLists.txt*.<br>
```cmake
build_latest_release(
        # The profile name hosting the git repository.
        PROFILE_NAME
        # The git repository name.
        REPOSITORY_NAME
        # The directory where the library directory will be created.
        DIRECTORY

        # --------- Optional parameters ---------

        # If the library has defined an install() function.
        INSTALL_ENABLED
        # Extra args to pass when building the library.
        BUILD_ARGS
)
```

## git_utils.cmake

- `get_latest_tag():` Returns the latest tag from the given repository info.<br>
```cmake
get_latest_tag(
        # The profile name hosting the git repository.
        PROFILE_NAME
        # The git repository name.
        REPOSITORY_NAME

        # --------- Optional parameters ---------
        
        # If the temporary directory containing the cloned repo needs to be deleted.
        CLEAR
        # Where the tag name will be stored.
        OUTPUT_VARIABLE
)
```
