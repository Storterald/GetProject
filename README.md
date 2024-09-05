# CMake Utilities Functions

Some utility functions for CMake. All functions use the `cmake_parse_arguments()` function. 
To call a function the parameter name must be specified.

### get_library.cmake

Requires the `git_utils.cmake` file.

- `get_file_from_fixed_url():` Fetches a file from a defined **URL**.<br>
  Parameters:
  - ***URL:*** The URL from where the file will be fetched.
  - ***DIRECTORY:*** The directory where the file will be stored.
  - ***FILE_NAME:*** The fetched file name.
  - ***FETCH_NEW:*** If the fetch must be done even if the file already exists.
- `build_library_from_fixed_url():` Fetches a library and builds it from the given **URL**. The library is required to have *CMakeLists.txt*.<br>
    Parameters:
  - ***TARGET:*** The target that depends on the library.
  - ***URL:*** The URL from where the library will be fetched.
  - ***DIRECTORY:*** The directory where the library directory will be created.
  - ***LIBRARY_NAME:*** The library name, also the name of the directory that will be created inside the directory parameter.
  - ***INSTALL_ENABLED:*** If the library has defined an install() function.
  - ***FETCH_NEW:*** If the fetch must be done even if the library already exists, required when building with a compiler
    that has a different output file format.
  - ***BUILD_ARGS:*** Optional extra args to pass to ExternalProject when building the library.
- `download_library_with_fixed_url():` Fetches a library from the given **URL**.<br>
    Parameters:
  - ***TARGET:*** The target that depends on the library.
  - ***URL:*** The URL from where the library will be fetched.
  - ***DIRECTORY:*** The directory where the library directory will be created.
  - ***LIBRARY_NAME:*** The library name, also the name of the directory that will be created inside the directory parameter.
  - ***FETCH_NEW:*** If the fetch must be done even if the library already exists, required when building with a compiler
    that has a different output file format.
- `build_library_with_git():` Fetches and builds the latest release of a library from GitHub. Uses **git**.
  The library is required to have a *CMakeLists.txt*.<br>
  Parameters:
  - ***TARGET:*** The target that depends on the library.
  - ***PROFILE_NAME:*** The profile name hosting the GitHub repository.
  - ***REPOSITORY_NAME:*** The GitHub repository name.
  - ***DIRECTORY:*** The directory where the library directory will be created.
  - ***INSTALL_ENABLED:*** If the library has defined an install() function.
  - ***FETCH_NEW:*** If the fetch must be done even if the library already exists, required when building with a compiler
    that has a different output file format.
  - ***BUILD_ARGS:*** Optional extra args to pass to ExternalProject when building the library.
- `download_library_with_git():` Fetches and builds the latest release of a library from GitHub. Uses **git**.<br>
    Parameters:
  - ***TARGET:*** The target that depends on the library.
  - ***PROFILE_NAME:*** The profile name hosting the GitHub repository.
  - ***REPOSITORY_NAME:*** The GitHub repository name.
  - ***DIRECTORY:*** The directory where the library directory will be created.
  - ***FETCH_NEW:*** If the fetch must be done even if the library already exists, required when building with a compiler
    that has a different output file format.
- `get_repo_file():` Fetches a file from a GitHub repository. Requires the branch name.<br>
  Parameters:
  - ***PROFILE_NAME:*** The profile name hosting the GitHub repository.
  - ***REPOSITORY_NAME:*** The GitHub repository name.
  - ***BRANCH_NAME:*** The branch containing the file.
  - ***FILE_PATH:*** The file path inside the repository.
  - ***DIRECTORY:*** The directory where the library directory will be created.
  - ***FETCH_NEW:*** If the fetch must be done even if the file already exists.

### git_utils.cmake

- `get_latest_tag():` Returns the latest tag from the given repository info.<br>
  Parameters:
  - ***PROFILE_NAME:*** The profile name hosting the GitHub repository.
  - ***REPOSITORY_NAME:*** The GitHub repository name.
  - ***OUTPUT_VARIABLE:*** Where the tag name will be stored.