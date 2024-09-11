cmake_minimum_required(VERSION 3.5)

# Fetches a file from a URL
function(get_file_from_fixed_url)
        # Parse args
        set(ONE_VALUE_ARGS URL DIRECTORY FILE_NAME FETCH_NEW)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (EXISTS "${ARGS_DIRECTORY}/${ARGS_FILE_NAME}")
                if (NOT ${ARGS_FETCH_NEW})
                        # Don't run if expected output exists already
                        message(STATUS "Expected output for file '${ARGS_FILE_NAME}' already exists. "
                                "Skipping fetching.")
                        return()
                else ()
                        # Delete expected output and run function
                        message(STATUS "Expected output for file '${ARGS_FILE_NAME}' already exists, "
                                "but 'FETCH_NEW' was set to true. Deleting file and re-fetching...")
                        file(REMOVE "${ARGS_DIRECTORY}/${ARGS_FILE_NAME}")
                endif ()
        endif ()

        # Download file
        message(STATUS "Fetching file '${ARGS_FILE_NAME}'...")
        file(DOWNLOAD ${ARGS_URL}
                "${ARGS_DIRECTORY}/${ARGS_FILE_NAME}"
                STATUS RESPONSE
                SHOW_PROGRESS
        )

        # Check if response is good
        if (NOT RESPONSE EQUAL 0)
                message(FATAL_ERROR "Failed to fetch file '${ARGS_FILE_NAME}', response: '${RESPONSE}'.")
        else ()
                message(STATUS "Successfully fetched file '${ARGS_FILE_NAME}'.")
        endif ()
endfunction()

# Downloads and builds a library from a fixed url
function(build_library_from_fixed_url)
        # Parse args
        set(ONE_VALUE_ARGS TARGET URL DIRECTORY LIBRARY_NAME INSTALL_ENABLED FETCH_NEW)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Get build directory
        set(LIBRARY_CMAKE_BINARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}/src/${ARGS_LIBRARY_NAME}-build")

        # Check if build directory was just generated or already used
        if (EXISTS "${LIBRARY_CMAKE_BINARY_DIR}/CMakeFiles")
                if (NOT ${ARGS_FETCH_NEW})
                        # Don't run if expected output exists already
                        message(STATUS "Expected output for library '${ARGS_LIBRARY_NAME}' already exists. "
                                "Skipping fetching and building.")
                        return()
                else ()
                        # Delete expected output and run function
                        message(STATUS "Expected output for library '${ARGS_LIBRARY_NAME}' already exists, "
                                "but 'FETCH_NEW' was set to true. Deleting file and re-fetching...")
                        file(REMOVE ${LIBRARY_CMAKE_BINARY_DIR})
                endif ()
        endif ()

        # Deleting previous build directory
        if (EXISTS ${LIBRARY_CMAKE_BINARY_DIR})
                message(STATUS "Found existing binary dir for library '${ARGS_LIBRARY_NAME}'. "
                        "Deleting it.")
                file(REMOVE_RECURSE ${LIBRARY_CMAKE_BINARY_DIR})
        endif ()

        # Include ExternalProject
        include(ExternalProject)

        # Fetch latest release
        if (${ARGS_INSTALL_ENABLED})
                externalproject_add(${ARGS_LIBRARY_NAME}
                        URL ${ARGS_URL}
                        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
                        PREFIX ${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}
                        CMAKE_ARGS
                        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                        -DCMAKE_INSTALL_PREFIX:PATH=${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}
                        ${ARGS_BUILD_ARGS}
                )
        else ()
                externalproject_add(${ARGS_LIBRARY_NAME}
                        URL ${ARGS_URL}
                        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
                        PREFIX ${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}
                        INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Skipping install step."
                        CMAKE_ARGS
                        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                        ${ARGS_BUILD_ARGS}
                )
        endif ()

        # Add build as dependency to target
        add_dependencies(${ARGS_TARGET} ${ARGS_LIBRARY_NAME})
endfunction()

# Downloads a library from the latest release on github
function(download_library_with_fixed_url)
        # Parse args
        set(ONE_VALUE_ARGS TARGET URL DIRECTORY LIBRARY_NAME FETCH_NEW)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Output directory
        set(OUT_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(TMP_DIR "${OUT_DIR}-tmp")

        if (EXISTS ${OUT_DIR})
                if (NOT ${ARGS_FETCH_NEW})
                        # Don't run if expected output exists already
                        message(STATUS "Expected output for library '${ARGS_LIBRARY_NAME}' already exists. "
                                "Skipping download.")
                        return()
                else ()
                        # Delete expected output and run function
                        message(STATUS "Expected output for library '${ARGS_LIBRARY_NAME}' already exists, "
                                "but 'FETCH_NEW' was set to true. Deleting files and re-fetching...")
                        file(REMOVE_RECURSE "${OUT_DIR}")
                endif ()
        endif ()

        # Include ExternalProject
        include(ExternalProject)

        # Fetch git library
        externalproject_add(${ARGS_LIBRARY_NAME}
                URL ${ARGS_URL}
                DOWNLOAD_EXTRACT_TIMESTAMP TRUE
                PREFIX ${TMP_DIR}
                CONFIGURE_COMMAND ${CMAKE_COMMAND} -E copy_directory "${TMP_DIR}/src/${ARGS_LIBRARY_NAME}" ${OUT_DIR}
                BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Skipping build step."
                INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Skipping install step."
        )

        # Delete temporary directory
        add_custom_command(
                TARGET ${ARGS_LIBRARY_NAME}
                COMMAND ${CMAKE_COMMAND} -E rm -rf ${TMP_DIR}
        )
endfunction()

# Downloads and builds a library from the latest release on github
function(build_library_with_git)
        # Parse args
        set(ONE_VALUE_ARGS TARGET PROFILE_NAME REPOSITORY_NAME DIRECTORY INSTALL_ENABLED FETCH_NEW)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (EXISTS "${DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                if (NOT ${ARGS_FETCH_NEW})
                        # Don't run if expected output exists already
                        message(STATUS "Expected output for library '${ARGS_REPOSITORY_NAME}' already exists. "
                                "Skipping download and build.")
                        return()
                else ()
                        # Delete expected output and run function
                        message(STATUS "Expected output for library '${ARGS_REPOSITORY_NAME}' already exists, "
                                "but 'FETCH_NEW' was set to true. Deleting files and re-fetching...")
                        file(REMOVE_RECURSE "${DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                endif ()
        endif ()

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        # Include git utils
        include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/git_utils.cmake)

        # Get latest git tag.
        get_latest_tag(
                PROFILE_NAME ${ARGS_PROFILE_NAME}
                REPOSITORY_NAME ${ARGS_REPOSITORY_NAME}
                CLEAR FALSE
                OUTPUT_VARIABLE TAG_NAME
        )

        # Include ExternalProject
        include(ExternalProject)

        # Fetch latest release
        build_library_from_fixed_url(
                TARGET ${ARGS_TARGET}
                URL "${GITHUB_URL}/archive/refs/tags/${TAG_NAME}.tar.gz"
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_REPOSITORY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                FETCH_NEW ${ARGS_FETCH_NEW}
                BUILD_ARGS ${ARGS_BUILD_ARGS}
        )
endfunction()

function(download_library_with_branch)
        # Parse args
        set(ONE_VALUE_ARGS TARGET PROFILE_NAME REPOSITORY_NAME BRANCH DIRECTORY)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        if (EXISTS "${DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                execute_process(
                        COMMAND git pull ${GITHUB_URL}
                        WORKING_DIRECTORY "${DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                )
        else ()
                execute_process(
                        COMMAND git clone ${GITHUB_URL} --branch ${ARGS_BRANCH} --single-branch "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                )
        endif ()
endfunction()

# Downloads a library from the latest release on github
function(download_library_with_git)
        # Parse args
        set(ONE_VALUE_ARGS TARGET PROFILE_NAME REPOSITORY_NAME DIRECTORY FETCH_NEW)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (EXISTS "${DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                if (NOT ${ARGS_FETCH_NEW})
                        # Don't run if expected output exists already
                        message(STATUS "Expected output for library '${ARGS_REPOSITORY_NAME}' already exists. "
                                "Skipping download.")
                        return()
                else ()
                        # Delete expected output and run function
                        message(STATUS "Expected output for library '${ARGS_REPOSITORY_NAME}' already exists, "
                                "but 'FETCH_NEW' was set to true. Deleting files and re-fetching...")
                        file(REMOVE_RECURSE "${DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                endif ()
        endif ()

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        # Include git utils
        include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/git_utils.cmake)

        # Get latest git tag.
        get_latest_tag(
                PROFILE_NAME ${ARGS_PROFILE_NAME}
                REPOSITORY_NAME ${ARGS_REPOSITORY_NAME}
                CLEAR FALSE
                OUTPUT_VARIABLE TAG_NAME
        )

        # Include ExternalProject
        include(ExternalProject)

        # Fetch latest release
        download_library_with_fixed_url(
                TARGET ${ARGS_TARGET}
                URL "${GITHUB_URL}/archive/refs/tags/${TAG_NAME}.tar.gz"
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_REPOSITORY_NAME}
                FETCH_NEW ${ARGS_FETCH_NEW}
        )
endfunction()

# Downloads a file from a repo branch
function(get_repo_file)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME BRANCH_NAME FILE_PATH DIRECTORY FETCH_NEW)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Gets file name from file path
        get_filename_component(FILE_NAME ${ARGS_FILE_PATH} NAME)

        get_file_from_fixed_url(
                URL "https://raw.githubusercontent.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}/${ARGS_BRANCH_NAME}/${ARGS_FILE_PATH}"
                DIRECTORY "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                FILE_NAME ${FILE_NAME}
                FETCH_NEW ${ARGS_FETCH_NEW}
        )
endfunction()