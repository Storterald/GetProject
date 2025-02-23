cmake_minimum_required(VERSION 3.5)

if (NOT DEFINED GET_PROJECT_OUTPUT_DIR)
        set(GET_PROJECT_OUTPUT_DIR "${CMAKE_HOME_DIRECTORY}/libs")
endif ()

# Let the user define their own GetProject internal directory
if (NOT DEFINED INTERNAL_GET_PROJECT_DIR)
        set(INTERNAL_GET_PROJECT_DIR "${CMAKE_BINARY_DIR}/GetProject")
endif ()

# Create GetProject internal directory if it does not exist
if (NOT EXISTS ${INTERNAL_GET_PROJECT_DIR})
        file(MAKE_DIRECTORY ${INTERNAL_GET_PROJECT_DIR})
endif ()

# ----------------------------------------------------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function (_check_internet_connection)
        set(ONE_VALUE_ARGS
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (WIN32)
                set(PING_COMMAND ping 8.8.8.8 -n 2)
        else ()
                set(PING_COMMAND ping 8.8.8.8 -c 2)
        endif ()

        execute_process(
                COMMAND ${PING_COMMAND}
                OUTPUT_QUIET
                ERROR_QUIET
                RESULT_VARIABLE DISCONNECTED)

        if (NOT DISCONNECTED GREATER 0)
                set(${ARGS_OUTPUT_VARIABLE} ON PARENT_SCOPE)
        else ()
                set(${ARGS_OUTPUT_VARIABLE} OFF PARENT_SCOPE)
        endif ()
endfunction ()

function (_get_latest_tag)
        set(ONE_VALUE_ARGS
                GIT_REPOSITORY
                LIBRARY_NAME
                CLEAR
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY OR NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_get_latest_tag, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories
        set(INTERNAL_LIBRARY_DIR "${INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/get_latest_tag")

        # Commands
        set(GIT_CLONE_COMMAND git clone ${ARGS_GIT_REPOSITORY}
                --depth 1
                --no-checkout
                --quiet
                ${CACHE_DIR})
        set(GIT_FETCH_COMMAND git fetch
                --tags
                --depth 1
                --quiet)
        set(GIT_PULL_COMMAND git pull
                --quiet)
        set(GIT_SORT_COMMAND git for-each-ref
                --sort=-creatordate
                --format "%(refname:short)"
                refs/tags)

        if (NOT EXISTS ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
        endif ()

        if (NOT EXISTS ${CACHE_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})

                # Clone repo with lowest depth possible and fetch tags, two
                # commands are needed as cmake does not wait for the first
                # command to finish execution before calling the second one.
                execute_process(COMMAND ${GIT_CLONE_COMMAND}
                        OUTPUT_QUIET
                        ERROR_QUIET)
                execute_process(COMMAND ${GIT_FETCH_COMMAND}
                        WORKING_DIRECTORY ${CACHE_DIR}
                        OUTPUT_QUIET
                        ERROR_QUIET)
        else ()
                execute_process(COMMAND ${GIT_PULL_COMMAND}
                        WORKING_DIRECTORY ${CACHE_DIR}
                        OUTPUT_QUIET
                        ERROR_QUIET)
        endif ()

        # Sort tags by creation date
        execute_process(
                COMMAND ${GIT_SORT_COMMAND}
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

        set(${ARGS_OUTPUT_VARIABLE} ${TAG_NAME} PARENT_SCOPE)
endfunction ()

function (_download_file)
        set(ONE_VALUE_ARGS
                URL
                HASH
                HASH_TYPE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_download_file, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Get archive name and extension
        get_filename_component(FILE_NAME ${ARGS_URL} NAME_WE)
        get_filename_component(FILE_EXT ${ARGS_URL} EXT)

        set(FILE_PATH "${GET_PROJECT_OUTPUT_DIR}/${FILE_NAME}${FILE_EXT}")

        if (ARGS_HASH)
                # Check if HASH_TYPE parameter was given
                if (NOT ARGS_HASH_TYPE)
                        message(FATAL_ERROR "HASH_TYPE must be provided when "
                                "passing HASH parameter to "
                                "download_file_from_url.")
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
endfunction ()

function (_is_directory_empty)
        set(ONE_VALUE_ARGS
                LIBRARY_DIR
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_LIBRARY_DIR OR NOT ARGS_OUTPUT_VARIABLE)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_is_directory_empty, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Used to check if directory is empty
        file(GLOB RESULT "${ARGS_LIBRARY_DIR}/**")
        list(LENGTH RESULT FILE_COUNT)

        # If library directory exists and it's not empty
        if (NOT EXISTS ${ARGS_LIBRARY_DIR} OR ${FILE_COUNT} EQUAL 0)
                set(${ARGS_OUTPUT_VARIABLE} ON PARENT_SCOPE)
        else ()
                set(${ARGS_OUTPUT_VARIABLE} OFF PARENT_SCOPE)
        endif ()
endfunction ()

function (_download_library_url)
        set(ONE_VALUE_ARGS
                URL
                LIBRARY_NAME)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL OR NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_download_library_url, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories and files
        set(INTERNAL_LIBRARY_DIR "${INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/download_library")
        set(TMP_DIR "${INTERNAL_LIBRARY_DIR}/.tmp")
        set(LIBRARY_DIR "${GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")
        set(HASH_FILE "${INTERNAL_LIBRARY_DIR}/hash")

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
        _download_file(
                URL ${ARGS_URL}
                DIRECTORY ${CACHE_DIR}
                HASH ${HASH}
                HASH_TYPE "MD5")

        # Get MD5 hash of the downloaded file and save it in NEW_HASH
        file(GLOB FILE_PATH "${CACHE_DIR}/**")
        file(MD5 ${FILE_PATH} NEW_HASH)

        # Don't waste time extracting stuff again if hashes match
        if (HASH AND "${NEW_HASH}" STREQUAL "${HASH}")
                _is_directory_empty(
                        LIBRARY_DIR ${LIBRARY_DIR}
                        OUTPUT_VARIABLE LIBRARY_DIR_EMPTY)

                if (NOT LIBRARY_DIR_EMPTY)
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
endfunction ()

function (_validate_git_repo)
        set(ONE_VALUE_ARGS GIT_REPOSITORY)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_validate_git_repo, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # If connected to the internet validate the git repository
        # without cloning.
        execute_process(
                COMMAND git ls-remote ${ARGS_GIT_REPOSITORY}
                RESULT_VARIABLE GIT_CHECK_RESULT
                OUTPUT_QUIET
                ERROR_QUIET)

        if(NOT GIT_CHECK_RESULT EQUAL 0)
                message(FATAL_ERROR "Invalid or inaccessible git repository "
                        "'${ARGS_GIT_REPOSITORY}'.")
        endif()
endfunction ()

function (_download_library_git)
        set(ONE_VALUE_ARGS
                GIT_REPOSITORY
                LIBRARY_DIR
                VERSION
                BRANCH
                KEEP_UPDATED)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY OR (NOT ARGS_BRANCH AND NOT ARGS_VERSION) OR NOT ARGS_LIBRARY_DIR)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_download_library_git, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Save the version or the branch in the COMMAND_BRANCH variable,
        # as you can use the --branch option to pass tags.
        if (NOT ARGS_BRANCH)
                set(COMMAND_BRANCH ${ARGS_VERSION})
        else ()
                set(COMMAND_BRANCH ${ARGS_BRANCH})
        endif ()

        # Commands
        set(GIT_CLONE_COMMAND ${GIT_EXECUTABLE} clone ${ARGS_GIT_REPOSITORY}
                --branch ${COMMAND_BRANCH}
                --recurse-submodules
                -j 8
                --depth 1
                -c advice.detachedHead=false
                --quiet
                ${ARGS_LIBRARY_DIR})
        set(GIT_PULL_COMMAND ${GIT_EXECUTABLE} pull ${ARGS_GIT_REPOSITORY}
                --quiet)

        if (EXISTS ${ARGS_LIBRARY_DIR})
                if (ARGS_BRANCH AND ARGS_KEEP_UPDATED)
                        execute_process(
                                COMMAND ${GIT_PULL_COMMAND}
                                WORKING_DIRECTORY ${ARGS_LIBRARY_DIR}
                                OUTPUT_QUIET
                                ERROR_QUIET)
                endif()
        else ()
                execute_process(
                        COMMAND ${GIT_CLONE_COMMAND}
                        OUTPUT_QUIET
                        ERROR_QUIET)
        endif ()
endfunction ()

function (_add_subdirectory)
        set(ONE_VALUE_ARGS
                LIBRARY_NAME
                INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS
                TARGETS
                OPTIONS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (NOT ARGS_TARGETS OR NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR
                        "Missing parameters in function call to "
                        "_add_subdirectory, please report this at the url "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories
        set(INTERNAL_LIBRARY_DIR "${INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(LIBRARY_DIR "${GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")
        set(BUILD_DIR "${LIBRARY_DIR}/build/${CMAKE_GENERATOR}-${CMAKE_BUILD_TYPE}")

        # If the library does not have CMake support. The inclusion must
        # be handled by the user.
        if (NOT EXISTS "${LIBRARY_DIR}/CMakeLists.txt")
                message(WARNING "CMakeLists.txt file not found in library "
                                "'${ARGS_LIBRARY_NAME}'. Not adding as a "
                                "subdirectory.")
                return ()
        endif ()

        # Define variables for external use.
        set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)
        set(${ARGS_LIBRARY_NAME}_BINARY ${BUILD_DIR} PARENT_SCOPE)

        # Define options
        set (REGEXP "^(.+)=(.+)$")
        foreach (OPTION IN LISTS ARGS_OPTIONS)
                if (NOT ${OPTION} MATCHES ${REGEXP})
                        message(FATAL_ERROR "Option '${OPTION}' not recognized. "
                                            "Use the format NAME=VALUE")
                endif ()

                string(REGEX MATCH ${REGEXP} OUT ${OPTION})
                set(${CMAKE_MATCH_1} ${CMAKE_MATCH_2})
        endforeach ()

        add_subdirectory(${LIBRARY_DIR} ${BUILD_DIR})

        # To install a directory it's required that the library is built.
        # TODO find something better
        if (ARGS_INSTALL_ENABLED)
                foreach (OPTION IN LISTS ARGS_OPTIONS)
                        list(APPEND DEFINITIONS "-D${OPTION}")
                endforeach ()

                set(CONFIG_ARGS
                        -G "${CMAKE_GENERATOR}"
                        -S ${LIBRARY_DIR}
                        -B ${BUILD_DIR}
                        -DCMAKE_INSTALL_PREFIX:PATH=${LIBRARY_DIR}
                        ${DEFINITIONS})

                set(BUILD_COMMAND --build ${BUILD_DIR})
                if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
                        set(BUILD_COMMAND ${BUILD_COMMAND} --config "${CMAKE_BUILD_TYPE}")
                endif ()

                set(INSTALL_COMMAND --build ${BUILD_DIR} --target install)
                if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
                        set(INSTALL_COMMAND ${INSTALL_COMMAND} --config "${CMAKE_BUILD_TYPE}")
                endif ()

                message(STATUS "GetProject: Installing ${ARGS_LIBRARY_NAME}...")

                execute_process(COMMAND ${CMAKE_COMMAND} . ${CONFIG_ARGS}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                execute_process(COMMAND ${CMAKE_COMMAND} ${BUILD_COMMAND}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                execute_process(COMMAND ${CMAKE_COMMAND} ${INSTALL_COMMAND}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                message(STATUS "GetProject: ${ARGS_LIBRARY_NAME} installed.")
        endif ()
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
                INSTALL_ENABLED
                DOWNLOAD_ONLY
                BRANCH
                KEEP_UPDATED
                VERSION)
        set(MULTI_VALUE_ARGS
                TARGETS
                OPTIONS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (NOT ARGS_URL)
                find_package(Git)
                if (NOT GIT_FOUND)
                        message(FATAL_ERROR
                                "Git is required to use GetProject without the "
                                "URL parameter. You can download git at "
                                "https://git-scm.com/downloads")
                endif ()
        endif ()

        if (ARGS_TARGET AND ARGS_TARGETS)
                message(FATAL_ERROR "Only one argument between ARGS_TARGET and "
                        "ARGS_TARGETS can be used.")
        endif ()

        if (ARGS_URL AND NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is required when passing an URL.")
        endif ()

        if (NOT ARGS_URL AND NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "Either URL or GIT_REPOSITORY is required "
                        "for get_library to do something.")
        endif ()

        if (NOT ARGS_BRANCH AND NOT "${ARGS_KEEP_UPDATED}" STREQUAL "")
                message(WARNING "KEEP_UPDATED argument is only used when the "
                        "BRANCH argument is passed.")
        endif ()

        if (ARGS_DOWNLOAD_ONLY AND ARGS_OPTIONS)
                message(WARNING "OPTIONS argument is only used when the DOWNLOAD_ONLY "
                        "argument is set to OFF.")
        endif ()

        if (NOT ARGS_DOWNLOAD_ONLY AND NOT ARGS_TARGET AND NOT ARGS_TARGETS)
                message(FATAL_ERROR "TARGET or TARGETS is required when DOWNLOAD_ONLY "
                        "is OFF.")
        endif ()

        if (NOT ARGS_URL AND NOT ARGS_BRANCH AND NOT ARGS_VERSION)
                message(WARNING "VERSION and BRANCH argument is missing, downloading "
                        "latest release...")
        endif ()

        # Check for internet connection
        _check_internet_connection(
                OUTPUT_VARIABLE IS_CONNECTED)

        # If the library is downloaded via git, validate the repo and get the name.
        if (ARGS_GIT_REPOSITORY)
                # If connected to the internet validate the git repository
                # without cloning
                if (IS_CONNECTED)
                        _validate_git_repo(GIT_REPOSITORY ${ARGS_GIT_REPOSITORY})
                endif ()

                # Extract the library name from the GIT_REPOSITORY parameter and
                # save it in ARGS_LIBRARY_NAME if the user didn't provide one.
                if (NOT ARGS_LIBRARY_NAME)
                        string(REGEX REPLACE ".*/([^/]+)\\.git$" "\\1"
                                ARGS_LIBRARY_NAME ${ARGS_GIT_REPOSITORY})
                endif ()
        endif ()

        # Directories and files
        set(INTERNAL_LIBRARY_DIR "${INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(LIBRARY_DIR "${GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")
        set(VERSION_FILE "${INTERNAL_LIBRARY_DIR}/version")

        if (NOT IS_CONNECTED)
                message(STATUS
                        "GetProject: Adding '${ARGS_LIBRARY_NAME}'. Since no "
                        "internet connection has been found, nothing can be "
                        "downloaded.")

                if (EXISTS ${LIBRARY_DIR} AND NOT ARGS_DOWNLOAD_ONLY)
                        _add_subdirectory(
                                TARGETS ${ARGS_TARGET} ${ARGS_TARGETS}
                                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                                OPTIONS ${ARGS_OPTIONS})
                        
                        set(${ARGS_LIBRARY_NAME}_DOWNLOADED ON PARENT_SCOPE)
                        set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)
                        set(${ARGS_LIBRARY_NAME}_BINARY ${${ARGS_LIBRARY_NAME}_BINARY} PARENT_SCOPE)
                endif ()

                return ()
        endif ()

        message(STATUS "GetProject: Adding '${ARGS_LIBRARY_NAME}'.")

        if (NOT ARGS_URL AND NOT ARGS_BRANCH)
                # Check if the given version is set as null or latest, if so
                # fetch the latest release.
                string(TOUPPER "${ARGS_VERSION}" CAPS_VERSION)
                if (NOT ARGS_VERSION OR "${CAPS_VERSION}" STREQUAL "LATEST")
                        _get_latest_tag(
                                GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                                CLEAR OFF
                                OUTPUT_VARIABLE ARGS_VERSION)
                endif ()

                # Save the library version.
                if (EXISTS ${INTERNAL_LIBRARY_DIR} AND EXISTS ${VERSION_FILE})
                        file(READ ${VERSION_FILE} DOWNLOADED_VERSION)

                        if (NOT "${DOWNLOADED_VERSION}" STREQUAL "${ARGS_VERSION}")
                                message(STATUS "Version mismatch for library "
                                        "'${ARGS_LIBRARY_NAME}'. "
                                        "Deleting and downloading...")

                                # If version does not match delete existing library
                                # and the version file.
                                file(REMOVE_RECURSE ${LIBRARY_DIR})
                                file(REMOVE ${VERSION_FILE})
                        else ()
                                _is_directory_empty(
                                        LIBRARY_DIR ${LIBRARY_DIR}
                                        OUTPUT_VARIABLE LIBRARY_DIR_EMPTY)

                                if (LIBRARY_DIR_EMPTY)
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
                _download_library_url(
                        URL ${ARGS_URL}
                        LIBRARY_NAME ${ARGS_LIBRARY_NAME})
        else ()
                _download_library_git(
                        GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                        LIBRARY_DIR ${LIBRARY_DIR}
                        VERSION ${ARGS_VERSION}
                        BRANCH ${ARGS_BRANCH}
                        KEEP_UPDATED ${ARGS_KEEP_UPDATED})
        endif ()

        set(${ARGS_LIBRARY_NAME}_DOWNLOADED ON PARENT_SCOPE)

        if (ARGS_DOWNLOAD_ONLY)
                return()
        endif ()

        _add_subdirectory(
                TARGETS ${ARGS_TARGET} ${ARGS_TARGETS}
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                OPTIONS ${ARGS_OPTIONS})

        set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)
        set(${ARGS_LIBRARY_NAME}_SOURCE ${LIBRARY_DIR} PARENT_SCOPE)
        set(${ARGS_LIBRARY_NAME}_BINARY ${${ARGS_LIBRARY_NAME}_BINARY} PARENT_SCOPE)
endfunction ()
