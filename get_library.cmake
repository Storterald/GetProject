cmake_minimum_required(VERSION 3.5)

# ----------------------------------------------------------------------------------------------------------------------
# URL FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

# Fetches a file from a URL
function(download_file_from_url)
        # Parse args
        set(ONE_VALUE_ARGS URL DIRECTORY HASH HASH_TYPE)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL is a mandatory parameter of download_file_from_url.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of download_file_from_url.")
        endif ()

        # Get archive name and extension
        get_filename_component(FILE_NAME ${ARGS_URL} NAME_WE)
        get_filename_component(FILE_EXT ${ARGS_URL} EXT)

        # Constants
        set(FILE_PATH "${ARGS_DIRECTORY}/${FILE_NAME}${FILE_EXT}")

        # Download file
        message(STATUS "Fetching file '${FILE_NAME}${FILE_EXT}'...")
        if (ARGS_HASH)
                # Check if HASH_TYPE parameter was given
                if (NOT ARGS_HASH_TYPE)
                        message(FATAL_ERROR "HASH_TYPE must be provided when passing HASH parameter "
                                "to download_file_from_url.")
                endif ()

                # Download file with hash comparison
                file(DOWNLOAD ${ARGS_URL}
                        ${FILE_PATH}
                        EXPECTED_HASH ${ARGS_HASH_TYPE}=${ARGS_HASH}
                        STATUS RESPONSE
                )
        else ()
                # Download file with hash comparison
                file(DOWNLOAD ${ARGS_URL}
                        ${FILE_PATH}
                        STATUS RESPONSE
                )
        endif ()

        # Check if response is good
        if (NOT RESPONSE EQUAL 0)
                message(FATAL_ERROR "Failed to download file '${FILE_NAME}${FILE_EXT}', "
                        "response: '${RESPONSE}'.")
        else ()
                message(STATUS "Successfully downloaded file '${FILE_NAME}${FILE_EXT}'.")
        endif ()
endfunction()

# Downloads a library from the latest release on github
function(download_from_url)
        # Parse args
        set(ONE_VALUE_ARGS URL DIRECTORY LIBRARY_NAME)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL is a mandatory parameter of download_from_url.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of download_from_url.")
        endif ()
        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is a mandatory parameter of download_from_url.")
        endif ()

        # Constants
        set(GET_LIBRARY_DIR "${CMAKE_BINARY_DIR}/get_library")
        set(LIBRARY_DIR "${GET_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}")
        set(LIBRARY_CACHE_DIR "${LIBRARY_DIR}/cache")
        set(LIBRARY_ARCHIVE_DIR "${LIBRARY_DIR}/archive")
        set(TMP_DIR "${LIBRARY_DIR}/.tmp")
        set(OUTPUT_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")

        # Create get_library internal directory
        if (NOT EXISTS ${GET_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${GET_LIBRARY_DIR})
        endif ()

        # Create library internal directory
        if (NOT EXISTS ${LIBRARY_DIR})
                file(MAKE_DIRECTORY ${LIBRARY_DIR})
                file(MAKE_DIRECTORY ${LIBRARY_CACHE_DIR})
                file(MAKE_DIRECTORY ${LIBRARY_ARCHIVE_DIR})
        else ()
                # Get the archive file hash
                file(GLOB HASH_FILE "${LIBRARY_CACHE_DIR}/*")

                # This should always be true unless the user manually
                # deleted the hash file
                if (HASH_FILE)
                        get_filename_component(HASH ${HASH_FILE} NAME_WE)
                endif ()
        endif ()

        # Download library archive
        download_file_from_url(
                URL ${ARGS_URL}
                DIRECTORY ${LIBRARY_ARCHIVE_DIR}
                HASH ${HASH}
                HASH_TYPE "MD5"
        )

        # Create new cached hash
        file(GLOB FILE_PATH "${LIBRARY_ARCHIVE_DIR}/**")
        file(MD5 ${FILE_PATH} NEW_HASH)

        # Don't waste time extracting stuff again if hashes match
        if (HASH AND "${NEW_HASH}" STREQUAL "${HASH}")
                # Used to check if directory is empty
                file(GLOB RESULT "${OUTPUT_DIR}/**")
                list(LENGTH RESULT FILE_COUNT)

                # If library directory exists and it's not empty
                if (NOT EXISTS ${OUTPUT_DIR} OR ${FILE_COUNT} EQUAL 0)
                        message(STATUS "Old and new downloaded file hashes match, "
                                "but '${ARGS_LIBRARY_NAME}' directory does not exist / is empty, "
                                "extracting...")
                else ()

                        message(STATUS "Old and new downloaded file hashes match. "
                                "Not Extracting.")
                        return()
                endif ()
        else ()
                message(STATUS "Old and new downloaded file hashes don't match, "
                        "extracting...")
        endif ()

        # Write hash file only if its different
        file(WRITE "${LIBRARY_CACHE_DIR}/${NEW_HASH}")

        # Delete old extracted data
        if (EXISTS ${OUTPUT_DIR})
                file(REMOVE_RECURSE ${OUTPUT_DIR})
        endif ()

        # Create temporary directory and extract archive there
        file(MAKE_DIRECTORY ${TMP_DIR})
        file(ARCHIVE_EXTRACT INPUT ${FILE_PATH} DESTINATION ${TMP_DIR})

        # Move the extracted content to library directory
        file(GLOB EXTRACTED_CONTENT "${TMP_DIR}/*/**")
        file(COPY ${EXTRACTED_CONTENT} DESTINATION ${OUTPUT_DIR})

        # Clean up the temporary directory
        file(REMOVE_RECURSE ${TMP_DIR})
endfunction()

# Downloads and builds a library from a fixed url
function(build_from_url)
        # Parse args
        set(ONE_VALUE_ARGS TARGET URL DIRECTORY LIBRARY_NAME INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_TARGET)
                message(FATAL_ERROR "TARGET is a mandatory parameter of build_from_url.")
        endif ()
        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL is a mandatory parameter of build_from_url.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of build_from_url.")
        endif ()
        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is a mandatory parameter of build_from_url.")
        endif ()

        # Constants
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${CMAKE_BINARY_DIR}/get_library/${ARGS_LIBRARY_NAME}/cache")
        set(BUILD_DIR "${LIBRARY_DIR}/build/${CMAKE_GENERATOR}-${CMAKE_BUILD_TYPE}")
        set(DEPENDENCY_FILE "${CMAKE_BINARY_DIR}/get_library/${ARGS_LIBRARY_NAME}/${ARGS_LIBRARY_NAME}.stamp")

        # Script arguments
        set(BUILD_ARGS
                -G "${CMAKE_GENERATOR}"
                -S ${LIBRARY_DIR}
                -B ${BUILD_DIR}
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DCMAKE_INSTALL_PREFIX:PATH=${LIBRARY_DIR}
                ${ARGS_BUILD_ARGS}
        )
        if (${ARGS_INSTALL_ENABLED})
                set(INSTALL_COMMAND --build ${BUILD_DIR} --target install)
        else ()
                set(INSTALL_COMMAND -E echo "Skipping install step.")
        endif ()

        # Download library at configure time
        download_from_url(
                URL ${ARGS_URL}
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
        )

        # The hash file can be used to determine if the build needs to happen
        file(GLOB CACHE_FILE "${CACHE_DIR}/**")

        # Configure, build and install the library
        add_custom_command(OUTPUT ${DEPENDENCY_FILE}
                COMMAND ${CMAKE_COMMAND} -E echo "Configuring ${ARGS_LIBRARY_NAME}..."
                COMMAND ${CMAKE_COMMAND} . ${BUILD_ARGS}
                COMMAND ${CMAKE_COMMAND} -E echo "Building ${ARGS_LIBRARY_NAME}..."
                COMMAND ${CMAKE_COMMAND} --build ${BUILD_DIR}
                COMMAND ${CMAKE_COMMAND} ${INSTALL_COMMAND}
                COMMAND ${CMAKE_COMMAND} -E touch ${DEPENDENCY_FILE}
                WORKING_DIRECTORY ${LIBRARY_DIR}
                DEPENDS ${CACHE_FILE}
        )

        # Add dependency to input target
        add_custom_target(${ARGS_LIBRARY_NAME} ALL DEPENDS ${DEPENDENCY_FILE})
        add_dependencies(${ARGS_TARGET} ${ARGS_LIBRARY_NAME})
endfunction()

# ----------------------------------------------------------------------------------------------------------------------
# BRANCH FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

# Downloads a file from a repo branch
function(download_file_from_branch)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME BRANCH FILE_PATH DIRECTORY)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_PROFILE_NAME)
                message(FATAL_ERROR "PROFILE_NAME is a mandatory parameter of download_file_from_branch.")
        endif ()
        if (NOT ARGS_REPOSITORY_NAME)
                message(FATAL_ERROR "REPOSITORY_NAME is a mandatory parameter of download_file_from_branch.")
        endif ()
        if (NOT ARGS_BRANCH)
                message(FATAL_ERROR "BRANCH is a mandatory parameter of download_file_from_branch.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of download_file_from_branch.")
        endif ()

        download_file_from_url(
                URL "https://raw.githubusercontent.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}/${ARGS_BRANCH}/${ARGS_FILE_PATH}"
                DIRECTORY "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
        )
endfunction()

# Clones a library or updates it if already cloned
function(download_from_branch)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME BRANCH DIRECTORY)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_PROFILE_NAME)
                message(FATAL_ERROR "PROFILE_NAME is a mandatory parameter of download_from_branch.")
        endif ()
        if (NOT ARGS_REPOSITORY_NAME)
                message(FATAL_ERROR "REPOSITORY_NAME is a mandatory parameter of download_from_branch.")
        endif ()
        if (NOT ARGS_BRANCH)
                message(FATAL_ERROR "BRANCH is a mandatory parameter of download_from_branch.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of download_from_branch.")
        endif ()

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        if (EXISTS "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}")
                execute_process(
                        COMMAND git pull ${GITHUB_URL}
                        WORKING_DIRECTORY "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
                )
        else ()
                execute_process(
                        COMMAND git clone ${GITHUB_URL} --branch ${ARGS_BRANCH} --depth 1 "${ARGS_DIRECTORY}/${ARGS_REPOSITORY_NAME}"
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

        # Validate parameters
        if (NOT ARGS_PROFILE_NAME)
                message(FATAL_ERROR "PROFILE_NAME is a mandatory parameter of download_latest_release.")
        endif ()
        if (NOT ARGS_REPOSITORY_NAME)
                message(FATAL_ERROR "REPOSITORY_NAME is a mandatory parameter of download_latest_release.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of download_latest_release.")
        endif ()

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        # Include git utils
        include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/git_utils.cmake")

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

        # Validate parameters
        if (NOT ARGS_TARGET)
                message(FATAL_ERROR "TARGET is a mandatory parameter of build_latest_release.")
        endif ()
        if (NOT ARGS_PROFILE_NAME)
                message(FATAL_ERROR "PROFILE_NAME is a mandatory parameter of build_latest_release.")
        endif ()
        if (NOT ARGS_REPOSITORY_NAME)
                message(FATAL_ERROR "REPOSITORY_NAME is a mandatory parameter of build_latest_release.")
        endif ()
        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a mandatory parameter of build_latest_release.")
        endif ()

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        # Include git utils
        include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/git_utils.cmake")

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