# CMake Utilities Functions

Some utility functions for CMake. Current files and functions:

 - `get_library.cmake`
   - **get_file_from_fixed_url():**
     Fetches a file from a defined **URL**.
   - **build_library_from_fixed_url():**
     Fetches a library and builds it. The library is required to have *CMakeLists.txt*.
   - **build_library_with_api():**
     Fetches and builds the latest release of a library from GitHub. Uses the free GitHub API. 
     The library is required to have a *CMakeLists.txt*.
   - **get_repo_file():**
     Fetches a file from a GitHub repository. Requires the branch name.