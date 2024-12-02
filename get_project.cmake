cmake_minimum_required(VERSION 3.5)

set(GET_PROJECT_DIR "${CMAKE_BINARY_DIR}/get_project")

# Create get_project internal directory if it does not exist
if (NOT EXISTS ${GET_PROJECT_DIR})
        file(MAKE_DIRECTORY ${GET_PROJECT_DIR})
endif ()

# ----------------------------------------------------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function(get_latest_tag)
        set(ONE_VALUE_ARGS
                GIT_REPOSITORY
                LIBRARY_NAME
                CLEAR
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "GIT_REPOSITORY is a required argument of get_latest_tag().")
        endif ()

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is a required argument of get_latest_tag().")
        endif ()

        # Directories
        set(INTERNAL_LIBRARY_DIR "${GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/get_latest_tag")

        if (NOT EXISTS ${LIBRARY_DIR})
                file(MAKE_DIRECTORY ${LIBRARY_DIR})
        endif ()

        if (NOT EXISTS ${CACHE_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})

                set(GIT_CLONE_COMMAND git clone ${ARGS_GIT_REPOSITORY}
                        --depth 1
                        --no-checkout
                        ${CACHE_DIR})
                set(GIT_FETCH_COMMAND git fetch
                        --tags
                        --depth 1)

                # Clone repo with lowest depth possible and fetch tags, two
                # commands are needed as cmake does not wait for the first command
                # to finish execution before calling the second one
                execute_process(COMMAND ${GIT_CLONE_COMMAND}
                        OUTPUT_QUIET)
                execute_process(COMMAND ${GIT_FETCH_COMMAND}
                        WORKING_DIRECTORY ${CACHE_DIR}
                        OUTPUT_QUIET)
        else ()
                message(STATUS "Cache folder for repository '${ARGS_GIT_REPOSITORY}' "
                        "exists, executing only 'git pull'.")

                set(GIT_PULL_COMMAND git pull)

                execute_process(COMMAND ${GIT_PULL_COMMAND}
                        WORKING_DIRECTORY ${CACHE_DIR})
        endif ()

        # Sort tags by creation date
        execute_process(
                COMMAND git for-each-ref --sort=-creatordate --format "%(refname:short)" refs/tags
                WORKING_DIRECTORY ${CACHE_DIR}
                OUTPUT_VARIABLE TAG_LIST
                OUTPUT_STRIP_TRAILING_WHITESPACE)

        # Delete downloaded content
        if (ARGS_CLEAR)
                file(REMOVE_RECURSE ${CACHE_DIR})
        endif ()

        # Checking if tag list was obtained correctly
        if (NOT TAG_LIST)
                message(FATAL_ERROR "Failed to obtain tag list.")
        endif ()

        # Get the latest tag from the tag list
        string(REGEX MATCH "([^ \n]+)" TAG_NAME ${TAG_LIST})
        set(TAG_NAME "${CMAKE_MATCH_1}")

        message(STATUS "Latest tag for repository '${ARGS_GIT_REPOSITORY}' "
                "has been found to be '${TAG_NAME}'")

        set(${ARGS_OUTPUT_VARIABLE} ${TAG_NAME} PARENT_SCOPE)
endfunction()

function(download_file)
        set(ONE_VALUE_ARGS
                URL
                DIRECTORY
                HASH
                HASH_TYPE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL is a required argument of download_file().")
        endif ()

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a required argument of download_file().")
        endif ()

        # Get archive name and extension
        get_filename_component(FILE_NAME ${ARGS_URL} NAME_WE)
        get_filename_component(FILE_EXT ${ARGS_URL} EXT)

        set(FILE_PATH "${ARGS_DIRECTORY}/${FILE_NAME}${FILE_EXT}")

        if (ARGS_HASH)
                # Check if HASH_TYPE parameter was given
                if (NOT ARGS_HASH_TYPE)
                        message(FATAL_ERROR "HASH_TYPE must be provided when passing HASH parameter "
                                "to download_file_from_url.")
                endif ()

                # Download file with hash comparison
                file(DOWNLOAD ${ARGS_URL} ${FILE_PATH}
                        EXPECTED_HASH ${ARGS_HASH_TYPE}=${ARGS_HASH}
                        STATUS RESPONSE)
        else ()
                # Download file without hash comparison
                file(DOWNLOAD ${ARGS_URL} ${FILE_PATH}
                        STATUS RESPONSE)
        endif ()

        # Check if response is good
        if (NOT RESPONSE EQUAL 0)
                message(FATAL_ERROR "Failed to download file '${FILE_NAME}${FILE_EXT}', "
                        "response: '${RESPONSE}'.")
        else ()
                message(STATUS "Correctly downloaded file '${FILE_NAME}${FILE_EXT}'.")
        endif()
endfunction()

function (is_library_directory_valid)
        set(ONE_VALUE_ARGS
                LIBRARY_DIR
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_LIBRARY_DIR)
                message(FATAL_ERROR "LIBRARY_DIR must be given to is_library_directory_valid().")
        endif ()

        if (NOT ARGS_OUTPUT_VARIABLE)
                message(FATAL_ERROR "OUTPUT_VARIABLE must be given to is_library_directory_valid().")
        endif ()

        # Used to check if directory is empty
        file(GLOB RESULT "${ARGS_LIBRARY_DIR}/**")
        list(LENGTH RESULT FILE_COUNT)

        # If library directory exists and it's not empty
        if (NOT EXISTS ${ARGS_LIBRARY_DIR} OR ${FILE_COUNT} EQUAL 0)
                set(${ARGS_OUTPUT_VARIABLE} OFF PARENT_SCOPE)
        else ()
                set(${ARGS_OUTPUT_VARIABLE} ON PARENT_SCOPE)
        endif ()
endfunction ()

function(download_library)
        set(ONE_VALUE_ARGS
                URL
                DIRECTORY
                LIBRARY_NAME)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL is a required argument of download_library().")
        endif ()

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a required argument of download_library().")
        endif ()

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is a required argument of download_library().")
        endif ()

        # Directories and files
        set(INTERNAL_LIBRARY_DIR "${GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/download_library")
        set(TMP_DIR "${INTERNAL_LIBRARY_DIR}/.tmp")
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(HASH_FILE "${INTERNAL_LIBRARY_DIR}/hash")
        set(BUILD_DEPENDENCY_FILE "${INTERNAL_LIBRARY_DIR}/build")

        # Create get_library internal directory
        if (NOT EXISTS ${GET_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${GET_LIBRARY_DIR})
        endif ()

        # Create library internal directory
        if (NOT EXISTS ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})
        else ()
                # This should always be true unless the user manually
                # deleted the hash file
                if (EXISTS ${HASH_FILE})
                        file(READ ${HASH_FILE} HASH)
                endif ()
        endif ()

        # Download library archive
        download_file(
                URL ${ARGS_URL}
                DIRECTORY ${CACHE_DIR}
                HASH ${HASH}
                HASH_TYPE "MD5")

        # Get MD5 hash of the downloaded file and save it in NEW_HASH
        file(GLOB FILE_PATH "${CACHE_DIR}/**")
        file(MD5 ${FILE_PATH} NEW_HASH)

        # Don't waste time extracting stuff again if hashes match
        if (HASH AND "${NEW_HASH}" STREQUAL "${HASH}")
                is_library_directory_valid(
                        LIBRARY_DIR ${LIBRARY_DIR}
                        OUTPUT_VARIABLE LIBRARY_DIR_VALID)

                if (LIBRARY_DIR_VALID)
                        message(STATUS "Old and new downloaded file hashes match, "
                                "but '${ARGS_LIBRARY_NAME}' directory does "
                                "not exist / is empty, extracting...")
                else ()
                        message(STATUS "Old and new downloaded file hashes match. "
                                "Not Extracting.")

                        return()
                endif ()
        else ()
                message(STATUS "Old and new downloaded file hashes don't match, "
                        "extracting...")
        endif ()

        execute_process(COMMAND ${CMAKE_COMMAND} -E touch ${BUILD_DEPENDENCY_FILE})

        # Write hash file only if its different
        file(WRITE ${HASH_FILE} ${NEW_HASH})

        # Delete old extracted data
        if (EXISTS ${LIBRARY_DIR})
                file(REMOVE_RECURSE ${LIBRARY_DIR})
        endif ()

        # Create temporary directory and extract archive there
        file(MAKE_DIRECTORY ${TMP_DIR})
        file(ARCHIVE_EXTRACT INPUT ${FILE_PATH} DESTINATION ${TMP_DIR})

        # Move the extracted content to library directory
        file(GLOB EXTRACTED_CONTENT "${TMP_DIR}/*/**")
        file(COPY ${EXTRACTED_CONTENT} DESTINATION ${LIBRARY_DIR})

        # Clean up the temporary directory
        file(REMOVE_RECURSE ${TMP_DIR})
endfunction()

function (build_library)
        set(ONE_VALUE_ARGS
                TARGET
                DIRECTORY
                LIBRARY_NAME
                INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS
                BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (NOT ARGS_TARGET)
                message(FATAL_ERROR "TARGET must be given to build_library().")
        endif ()

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY must be given to build_library().")
        endif ()

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME must be given to build_library().")
        endif ()

        # Directories and files
        set(GET_LIBRARY_DIR "${CMAKE_BINARY_DIR}/get_project")
        set(INTERNAL_LIBRARY_DIR "${GET_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/build_library")
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(BUILD_DIR "${LIBRARY_DIR}/build/${CMAKE_GENERATOR}-${CMAKE_BUILD_TYPE}")
        set(BUILD_DEPENDENCY_FILE "${INTERNAL_LIBRARY_DIR}/build")

        # Configure options
        set(BUILD_ARGS
                -G "${CMAKE_GENERATOR}"
                -S ${LIBRARY_DIR}
                -B ${BUILD_DIR}
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
                -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DCMAKE_INSTALL_PREFIX:PATH=${LIBRARY_DIR}
                ${ARGS_BUILD_ARGS})

        set(BUILD_COMMAND --build ${BUILD_DIR})
        if (MSVC)
                set(BUILD_COMMAND ${BUILD_COMMAND} --config "${CMAKE_BUILD_TYPE}")
        endif ()

        if (ARGS_INSTALL_ENABLED)
                set(INSTALL_COMMAND --build ${BUILD_DIR} --target install)
                if (MSVC)
                        set(INSTALL_COMMAND ${INSTALL_COMMAND} --config "${CMAKE_BUILD_TYPE}")
                endif ()
        else ()
                set(INSTALL_COMMAND -E echo "Skipping install step.")
        endif ()

        # Configure, build and install the library. The hash file can be used
        # to determine if the build needs to happen.
        set(DEPENDENCY_FILE "${INTERNAL_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}.stamp")
        add_custom_command(OUTPUT ${DEPENDENCY_FILE}
                COMMAND ${CMAKE_COMMAND} -E echo "Configuring ${ARGS_LIBRARY_NAME}..."
                COMMAND ${CMAKE_COMMAND} . ${BUILD_ARGS}
                COMMAND ${CMAKE_COMMAND} -E echo "Building ${ARGS_LIBRARY_NAME}..."
                COMMAND ${CMAKE_COMMAND} ${BUILD_COMMAND}
                COMMAND ${CMAKE_COMMAND} ${INSTALL_COMMAND}
                COMMAND ${CMAKE_COMMAND} -E touch ${DEPENDENCY_FILE}
                WORKING_DIRECTORY ${LIBRARY_DIR}
                DEPENDS ${BUILD_DEPENDENCY_FILE})

        # Add dependency to input target
        set(LIBRARY_TARGET "${ARGS_LIBRARY_NAME}_target")
        add_custom_target(${LIBRARY_TARGET} ALL DEPENDS ${DEPENDENCY_FILE})
        add_dependencies(${ARGS_TARGET} ${LIBRARY_TARGET})
endfunction ()

# ----------------------------------------------------------------------------------------------------------------------
# END-USER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function (get_project)
        set(ONE_VALUE_ARGS
                TARGET
                URL
                LIBRARY_NAME
                GIT_REPOSITORY
                DIRECTORY
                INSTALL_ENABLED
                DOWNLOAD_ONLY
                BRANCH
                KEEP_UPDATED
                VERSION)
        set(MULTI_VALUE_ARGS
                BUILD_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY is a required argument of get_project().")
        endif ()

        if (ARGS_URL AND NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is required when passing an URL.")
        endif ()

        if (NOT ARGS_URL AND NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "Either URL or GIT_REPOSITORY is required for get_library "
                        "to do something.")
        endif ()

        if (NOT ARGS_BRANCH AND NOT "${ARGS_KEEP_UPDATED}" STREQUAL "")
                message(WARNING "KEEP_UPDATED argument is only used when the BRANCH argument "
                        "is passed.")
        endif ()

        if (ARGS_DOWNLOAD_ONLY AND ARGS_BUILD_ARGS)
                message(WARNING "BUILD_ARGS argument is only used when the DOWNLOAD_ONLY "
                        "argument is set to OFF.")
        endif ()

        if (NOT ARGS_DOWNLOAD_ONLY AND NOT ARGS_TARGET)
                message(FATAL_ERROR "TARGET is required when DOWNLOAD_ONLY is OFF.")
        endif ()

        if (ARGS_GIT_REPOSITORY)
                # Validate git repository without cloning
                execute_process(
                        COMMAND git ls-remote ${ARGS_GIT_REPOSITORY}
                        RESULT_VARIABLE GIT_CHECK_RESULT
                        OUTPUT_QUIET
                        ERROR_QUIET)

                if(NOT GIT_CHECK_RESULT EQUAL 0)
                        message(FATAL_ERROR "Invalid or inaccessible git repository '${ARGS_GIT_REPOSITORY}'.")
                endif()

                # Extract the library name from the GIT_REPOSITORY parameter and
                # save it in ARGS_LIBRARY_NAME if the user didn't provide one.
                if (NOT ARGS_LIBRARY_NAME)
                        string(REGEX REPLACE ".*/([^/]+)\\.git$" "\\1" ARGS_LIBRARY_NAME ${ARGS_GIT_REPOSITORY})
                endif ()
        endif ()

        # If using the LATEST VERSION option, or if not using BRANCH and VERSION
        # is not specified, put the latest tag in ARGS_VERSION.
        if (NOT ARGS_URL AND NOT ARGS_BRANCH)
                if (ARGS_VERSION)
                        string(TOUPPER "${ARGS_VERSION}" ARGS_VERSION)
                else ()
                        message(WARNING "VERSION argument is missing, downloading latest release...")
                endif ()

                if (NOT ARGS_VERSION OR "${ARGS_VERSION}" STREQUAL "LATEST")
                        get_latest_tag(
                                GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                                CLEAR OFF
                                OUTPUT_VARIABLE ARGS_VERSION)
                endif ()
        endif ()

        # Directories and files
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")
        set(INTERNAL_LIBRARY_DIR "${GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(VERSION_FILE "${INTERNAL_LIBRARY_DIR}/version")
        set(BUILD_DEPENDENCY_FILE "${INTERNAL_LIBRARY_DIR}/build")

        if (NOT ARGS_URL)
                set(BOOL TOUCH_FILE ON)
        else ()
                # Managed by download_library()
                set(BOOL TOUCH_FILE OFF)
        endif ()

        if (NOT EXISTS ${BUILD_DEPENDENCY_FILE} AND NOT ARGS_DOWNLOAD_ONLY)
                # Will trigger dependency on creation.
                file(WRITE ${BUILD_DEPENDENCY_FILE})
        endif ()

        if (ARGS_VERSION AND NOT "${ARGS_VERSION}" STREQUAL "LATEST")
                if (EXISTS ${INTERNAL_LIBRARY_DIR} AND EXISTS ${VERSION_FILE})
                        file(READ ${VERSION_FILE} DOWNLOADED_VERSION)

                        if (NOT "${DOWNLOADED_VERSION}" STREQUAL "${ARGS_VERSION}")
                                # If version does not match delete existing library
                                # and the version file.
                                message(STATUS "Downloaded library '${ARGS_LIBRARY_NAME}' version "
                                        "'${DOWNLOADED_VERSION}' does not match requested "
                                        "version '${ARGS_VERSION}', deleting existing one...")

                                file(REMOVE_RECURSE ${LIBRARY_DIR})
                                file(REMOVE ${VERSION_FILE})
                        else ()
                                is_library_directory_valid(
                                        LIBRARY_DIR ${LIBRARY_DIR}
                                        OUTPUT_VARIABLE LIBRARY_DIR_VALID)

                                if (LIBRARY_DIR_VALID)
                                        # Don't do anything if versions match.
                                        message(STATUS "Previously downloaded library '${ARGS_LIBRARY_NAME}' version "
                                                "'${DOWNLOADED_VERSION}' matches requested version "
                                                "'${ARGS_VERSION}', not doing anything.")

                                        set(TOUCH_FILE OFF)
                                else ()
                                        message(STATUS "Previously downloaded library '${ARGS_LIBRARY_NAME}' version "
                                                "'${DOWNLOADED_VERSION}' matches requested version "
                                                "'${ARGS_VERSION}', but directory is missing / empty, "
                                                "cloning...")

                                        if (EXISTS ${LIBRARY_DIR})
                                                file(REMOVE_RECURSE ${LIBRARY_DIR})
                                        endif ()
                                endif ()
                        endif ()
                else ()
                        file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
                endif ()

                # Create current version file.
                file(WRITE "${INTERNAL_LIBRARY_DIR}/version" ${ARGS_VERSION})
        endif ()

        if (ARGS_URL)
                download_library(
                        URL ${ARGS_URL}
                        DIRECTORY ${ARGS_DIRECTORY}
                        LIBRARY_NAME ${ARGS_LIBRARY_NAME})
        else ()
                # Save the version or the branch in the COMMAND_BRANCH variable,
                # as you can use the --branch option to pass tags.
                if (NOT ARGS_BRANCH)
                        set(COMMAND_BRANCH ${ARGS_VERSION})
                else ()
                        set(COMMAND_BRANCH ${ARGS_BRANCH})
                endif ()

                # Constants
                set(GIT_PULL_COMMAND git pull ${ARGS_GIT_REPOSITORY})
                set(GIT_CLONE_COMMAND git clone ${ARGS_GIT_REPOSITORY}
                        --branch ${COMMAND_BRANCH}
                        --recurse-submodules
                        -j 8
                        --depth 1
                        -c advice.detachedHead=false
                        ${LIBRARY_DIR})

                if (EXISTS ${LIBRARY_DIR})
                        if (ARGS_BRANCH AND ARGS_KEEP_UPDATED)
                                execute_process(
                                        COMMAND ${GIT_PULL_COMMAND}
                                        WORKING_DIRECTORY ${LIBRARY_DIR})
                        endif()
                else ()
                        execute_process(
                                COMMAND ${GIT_CLONE_COMMAND}
                                OUTPUT_QUIET)
                endif ()
        endif ()

        if (ARGS_DOWNLOAD_ONLY)
                return()
        endif ()

        if (TOUCH_FILE)
                execute_process(COMMAND ${CMAKE_COMMAND} -E touch ${BUILD_DEPENDENCY_FILE})
        endif ()

        build_library(
                TARGET ${ARGS_TARGET}
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                BUILD_ARGS ${ARGS_BUILD_ARGS})
endfunction()
