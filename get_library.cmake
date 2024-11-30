cmake_minimum_required(VERSION 3.5)

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
                message(FATAL_ERROR "GIT_REPOSITORY must be given to get_latest_tag().")
        endif ()

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME must be given to get_latest_tag().")
        endif ()

        # Constants
        set(GIT_UTILS_DIR "${CMAKE_BINARY_DIR}/git_utils")
        set(CACHE_DIR "${GIT_UTILS_DIR}/${ARGS_LIBRARY_NAME}")

        # Create git_utils internal directory if it does not exist
        if (NOT EXISTS ${GIT_UTILS_DIR})
                file(MAKE_DIRECTORY ${GIT_UTILS_DIR})
        endif ()

        if (NOT EXISTS ${CACHE_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})

                # Clone repo with lowest depth possible and fetch tags, two
                # commands are needed as cmake does not wait for the first command
                # to finish execution before calling the second one
                execute_process(
                        COMMAND git clone --depth 1 --no-checkout ${ARGS_GIT_REPOSITORY} "."
                        WORKING_DIRECTORY ${CACHE_DIR}
                )
                execute_process(
                        COMMAND git fetch --tags --depth 1
                        WORKING_DIRECTORY ${CACHE_DIR}
                )
        else ()
                if (CMAKE_VERBOSE_MAKEFILE)
                        message(STATUS "Cached folder for repository '${ARGS_GIT_REPOSITORY}', "
                                "executing only 'git pull'.")
                endif ()
                execute_process(
                        COMMAND git pull
                        WORKING_DIRECTORY ${CACHE_DIR}
                )
        endif ()

        # Sort tags by creation date
        execute_process(
                COMMAND git for-each-ref --sort=-creatordate --format "%(refname:short)" refs/tags
                WORKING_DIRECTORY ${CACHE_DIR}
                OUTPUT_VARIABLE TAG_LIST
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        # Delete downloaded content
        if (ARGS_CLEAR)
                file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/${CACHE_DIR}")
        endif ()

        # Checking if tag list was obtained correctly
        if (NOT TAG_LIST)
                message(FATAL_ERROR "Failed to obtain tag list.")
        endif ()

        # Get the latest tag from the tag list
        string(REGEX MATCH "([^ \n]+)" TAG_NAME ${TAG_LIST})
        set(TAG_NAME "${CMAKE_MATCH_1}")

        if (CMAKE_VERBOSE_MAKEFILE)
                message(STATUS "Latest tag for repository '${ARGS_GIT_REPOSITORY}' "
                        "has been found to be '${TAG_NAME}'")
        endif ()

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
                message(FATAL_ERROR "URL must be given to download_file().")
        endif ()

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY must be given to download_file().")
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
                        STATUS RESPONSE
                )
        else ()
                # Download file without hash comparison
                file(DOWNLOAD ${ARGS_URL} ${FILE_PATH}
                        STATUS RESPONSE
                )
        endif ()

        # Check if response is good
        if (NOT RESPONSE EQUAL 0)
                message(FATAL_ERROR "Failed to download file '${FILE_NAME}${FILE_EXT}', "
                        "response: '${RESPONSE}'.")
        elseif (CMAKE_VERBOSE_MAKEFILE)
                message(STATUS "Correctly downloaded file '${FILE_NAME}${FILE_EXT}'.")
        endif()
endfunction()

function(download_library)
        set(ONE_VALUE_ARGS
                URL
                DIRECTORY
                LIBRARY_NAME)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL)
                message(FATAL_ERROR "URL must be given to download_library().")
        endif ()

        if (NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "DIRECTORY must be given to download_library().")
        endif ()

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME must be given to download_library().")
        endif ()

        # Directories
        set(GET_LIBRARY_DIR "${CMAKE_BINARY_DIR}/get_library")
        set(INTERNAL_LIBRARY_DIR "${GET_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}")
        set(LIBRARY_CACHE_DIR "${INTERNAL_LIBRARY_DIR}/cache")
        set(LIBRARY_ARCHIVE_DIR "${INTERNAL_LIBRARY_DIR}/archive")
        set(TMP_DIR "${INTERNAL_LIBRARY_DIR}/.tmp")
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")

        # Create get_library internal directory
        if (NOT EXISTS ${GET_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${GET_LIBRARY_DIR})
        endif ()

        # Create library internal directory
        if (NOT EXISTS ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
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
        download_file(
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
                file(GLOB RESULT "${LIBRARY_DIR}/**")
                list(LENGTH RESULT FILE_COUNT)

                # If library directory exists and it's not empty
                if (NOT EXISTS ${LIBRARY_DIR} OR ${FILE_COUNT} EQUAL 0)
                        if (CMAKE_VERBOSE_MAKEFILE)
                                message(STATUS "Old and new downloaded file hashes match, "
                                        "but '${ARGS_LIBRARY_NAME}' directory does not exist / is empty, "
                                        "extracting...")
                        endif()
                else ()
                        if (CMAKE_VERBOSE_MAKEFILE)
                                message(STATUS "Old and new downloaded file hashes match. "
                                        "Not Extracting.")
                        endif ()

                        return()
                endif ()
        else ()
                if(CMAKE_VERBOSE_MAKEFILE)
                        message(STATUS "Old and new downloaded file hashes don't match, "
                                "extracting...")
                endif ()
        endif ()

        # Write hash file only if its different
        file(WRITE "${LIBRARY_CACHE_DIR}/${NEW_HASH}")

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

        # Constants
        set(GET_LIBRARY_DIR "${CMAKE_BINARY_DIR}/get_library")
        set(INTERNAL_LIBRARY_DIR "${GET_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/cache")
        set(DEPENDENCY_FILE "${INTERNAL_LIBRARY_DIR}/${ARGS_LIBRARY_NAME}.stamp")
        set(BUILD_DIR "${LIBRARY_DIR}/build/${CMAKE_GENERATOR}-${CMAKE_BUILD_TYPE}")
        set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")

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

        if (ARGS_INSTALL_ENABLED)
                set(INSTALL_COMMAND --build ${BUILD_DIR} --target install)
        else ()
                set(INSTALL_COMMAND -E echo "Skipping install step.")
        endif ()

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
        add_custom_target(${ARGS_LIBRARY_NAME}_target ALL DEPENDS ${DEPENDENCY_FILE})
        add_dependencies(${ARGS_TARGET} ${ARGS_LIBRARY_NAME}_target)
endfunction ()

# ----------------------------------------------------------------------------------------------------------------------
# END-USER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function (get_library)
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
                message(FATAL_ERROR "DIRECTORY is a mandatory argument of get_library.")
        endif ()

        if (ARGS_URL AND NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME must be given when using the URL argument.")
        endif ()

        if (NOT ARGS_URL AND NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "Either URL or GIT_REPOSITORY must be given for get_library "
                        "to do something.")
        endif ()

        if (NOT ARGS_BRANCH AND NOT "${ARGS_KEEP_UPDATED}" STREQUAL "")
                message(WARNING "KEEP_UPDATED argument is only used when the BRANCH argument "
                        "is passed.")
        endif ()

        if (NOT ARGS_URL AND ARGS_LIBRARY_NAME)
                message(WARNING "LIBRARY_NAME argument is only used when the URL argument "
                        "is passed.")
        endif ()

        if (ARGS_DOWNLOAD_ONLY AND ARGS_BUILD_ARGS)
                message(WARNING "BUILD_ARGS argument is only used when the DOWNLOAD_ONLY "
                        "argument is set to OFF.")
        endif ()

        if (ARGS_GIT_REPOSITORY)
                # Validate git repository without cloning
                execute_process(
                        COMMAND git ls-remote ${ARGS_GIT_REPOSITORY}
                        RESULT_VARIABLE GIT_CHECK_RESULT
                        OUTPUT_QUIET
                        ERROR_QUIET
                )

                if(NOT GIT_CHECK_RESULT EQUAL 0)
                        message(FATAL_ERROR "Invalid or inaccessible git repository '${ARGS_GIT_REPOSITORY}'.")
                endif()

                string(REGEX REPLACE ".*/([^/]+)\\.git$" "\\1" ARGS_LIBRARY_NAME ${ARGS_GIT_REPOSITORY})
        endif ()

        # Put in the ARGS_BRANCH variable the tag
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
                                OUTPUT_VARIABLE ARGS_VERSION
                        )
                endif ()
        endif ()

        if (ARGS_URL)
                download_library(
                        URL ${ARGS_URL}
                        DIRECTORY ${ARGS_DIRECTORY}
                        LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                )
        else ()
                # Save the version in the ARGS_BRANCH variable, as you can use
                # the --branch option to pass tags.
                if (NOT ARGS_BRANCH)
                        set(ARGS_BRANCH ${ARGS_VERSION})
                endif ()

                set(LIBRARY_DIR "${ARGS_DIRECTORY}/${ARGS_LIBRARY_NAME}")

                if (EXISTS ${LIBRARY_DIR})
                        if (ARGS_KEEP_UPDATED)
                                execute_process(
                                        COMMAND git pull ${ARGS_GIT_REPOSITORY}
                                        WORKING_DIRECTORY ${LIBRARY_DIR}
                                )
                        endif()
                else ()
                        execute_process(
                                COMMAND git clone ${ARGS_GIT_REPOSITORY} --branch ${ARGS_BRANCH} --recurse-submodules -j 8 --depth 1 ${LIBRARY_DIR}
                        )
                endif ()
        endif ()

        if (ARGS_DOWNLOAD_ONLY)
                return()
        endif ()

        if (NOT ARGS_TARGET)
                message(FATAL_ERROR "TARGET must be given when DOWNLOAD_ONLY is OFF.")
        endif ()

        build_library(
                TARGET ${ARGS_TARGET}
                DIRECTORY ${ARGS_DIRECTORY}
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                BUILD_ARGS ${ARGS_BUILD_ARGS}
        )

endfunction()
