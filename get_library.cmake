cmake_minimum_required(VERSION 3.5)

# ----------------------------------------------------------------------------------------------------------------------
# URL DEPENDANT FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

# Fetches a file from a URL
function(download_file_from_url)
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

# Downloads a library from the latest release on github
function(download_from_url)
        # Parse args
        set(ONE_VALUE_ARGS URL DIRECTORY LIBRARY_NAME)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Include ExternalProject
        include(FetchContent)

        fetchcontent_declare(${ARGS_LIBRARY_NAME}
                URL ${ARGS_URL}
                SOURCE_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}"
                DOWNLOAD_EXTRACT_TIMESTAMP ON
        )

        # Check if the library needs to be downloaded
        fetchcontent_getproperties(${ARGS_LIBRARY_NAME})
        if (NOT ${ARGS_LIBRARY_NAME}_POPULATED)
                message(STATUS "'${ARGS_LIBRARY_NAME}' not downloaded, downloading...")
                fetchcontent_populate(${ARGS_LIBRARY_NAME})
        else ()
                message(STATUS "'${ARGS_LIBRARY_NAME}' already downloaded.")
        endif ()
endfunction()

# Downloads and builds a library from a fixed url
function(build_from_url)
        # Parse args
        set(ONE_VALUE_ARGS TARGET URL DIRECTORY LIBRARY_NAME INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Download library at configure time
        download_from_url(
                URL ${ARGS_URL}
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
        )

        set(LIBRARY_DIRECTORY "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(BUILD_ARGS
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DCMAKE_INSTALL_PREFIX:PATH=${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}
                ${ARGS_BUILD_ARGS}
        )

        # Library target
        add_custom_target(${ARGS_LIBRARY_NAME})

        if (${ARGS_INSTALL_ENABLED})
                set(INSTALL_COMMAND --target install)
        endif ()

        # Configure, build and install the library
        add_custom_command(TARGET ${ARGS_LIBRARY_NAME}
                COMMAND ${CMAKE_COMMAND} -E echo "Configuring ${ARGS_LIBRARY_NAME}..."
                COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}" "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}" ${BUILD_ARGS}
                COMMAND ${CMAKE_COMMAND} -E echo "Building ${ARGS_LIBRARY_NAME}... '$<IF:$<BOOL:${ARGS_INSTALL_ENABLED}>,--build . --target install,--build . >'"
                COMMAND ${CMAKE_COMMAND} --build . ${INSTALL_COMMAND}
                WORKING_DIRECTORY ${LIBRARY_DIRECTORY}
        )

        add_dependencies(${ARGS_TARGET} ${ARGS_LIBRARY_NAME})
endfunction()

# ----------------------------------------------------------------------------------------------------------------------
# BRANCH DEPENDANT FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

# Downloads a file from a repo branch
function(download_file_from_branch)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME BRANCH_NAME FILE_PATH DIRECTORY FETCH_NEW)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Gets file name from file path
        get_filename_component(FILE_NAME ${ARGS_FILE_PATH} NAME)

        download_file_from_url(
                URL "https://raw.githubusercontent.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}/${ARGS_BRANCH_NAME}/${ARGS_FILE_PATH}"
                DIRECTORY "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                FILE_NAME ${FILE_NAME}
                FETCH_NEW ${ARGS_FETCH_NEW}
        )
endfunction()

# Clones a library or updates it if already cloned
function(download_from_branch)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME BRANCH DIRECTORY)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        if (EXISTS "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                execute_process(
                        COMMAND git pull ${GITHUB_URL}
                        WORKING_DIRECTORY "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                )
        else ()
                execute_process(
                        COMMAND git clone ${GITHUB_URL} --branch ${ARGS_BRANCH} --single-branch "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                )
        endif ()
endfunction()

# ----------------------------------------------------------------------------------------------------------------------
# LATEST PUBLIC RELEASE FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

# Downloads a library from the latest release on github
function(download_latest_release)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME DIRECTORY)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

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

        # Fetch latest release
        download_from_url(
                URL "${GITHUB_URL}/archive/refs/tags/${TAG_NAME}.tar.gz"
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_REPOSITORY_NAME}
        )
endfunction()

# Downloads and builds a library from the latest release on github
function(build_latest_release)
        # Parse args
        set(ONE_VALUE_ARGS TARGET PROFILE_NAME REPOSITORY_NAME DIRECTORY INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

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

        # Fetch latest release
        build_from_url(
                TARGET ${ARGS_TARGET}
                URL "${GITHUB_URL}/archive/refs/tags/${TAG_NAME}.tar.gz"
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_REPOSITORY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                BUILD_ARGS ${ARGS_BUILD_ARGS}
        )
endfunction()