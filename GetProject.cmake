cmake_minimum_required(VERSION 3.10)

if (DEFINED GET_PROJECT_OUTPUT_DIR AND NOT DEFINED ENV{GET_PROJECT_OUTPUT_DIR})
        set(ENV{GET_PROJECT_OUTPUT_DIR} "${GET_PROJECT_OUTPUT_DIR}")
endif ()
if (NOT DEFINED ENV{GET_PROJECT_OUTPUT_DIR})
        set(ENV{GET_PROJECT_OUTPUT_DIR} "${CMAKE_HOME_DIRECTORY}/libs")
endif ()

if (DEFINED INTERNAL_GET_PROJECT_DIR AND NOT DEFINED ENV{INTERNAL_GET_PROJECT_DIR})
        set(ENV{INTERNAL_GET_PROJECT_DIR} "${INTERNAL_GET_PROJECT_DIR}")
endif ()
if (NOT DEFINED ENV{INTERNAL_GET_PROJECT_DIR})
        set(ENV{INTERNAL_GET_PROJECT_DIR} "${CMAKE_BINARY_DIR}/GetProject")
endif ()

# Create GetProject internal directory if it does not exist
if (NOT EXISTS $ENV{INTERNAL_GET_PROJECT_DIR})
        file(MAKE_DIRECTORY $ENV{INTERNAL_GET_PROJECT_DIR})
endif ()

# ----------------------------------------------------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function (_validate_args)
        set(ONE_VALUE_ARGS
                URL
                GIT_REPOSITORY
                FILE
                LIBRARY_NAME
                INSTALL_ENABLED
                DOWNLOAD_ONLY
                BRANCH
                KEEP_UPDATED
                VERSION)
        set(MULTI_VALUE_ARGS
                OPTIONS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (ARGS_URL AND NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "LIBRARY_NAME is required when passing an URL.")
        endif ()

        if (NOT ARGS_URL AND NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "Either URL or GIT_REPOSITORY is required "
                        "for get_project to do something.")
        endif ()

        if (ARGS_FILE AND NOT ARGS_URL)
                message(FATAL_ERROR "FILE boolean argument must be used along URL")
        endif ()

        if (NOT ARGS_BRANCH AND NOT "${ARGS_KEEP_UPDATED}" STREQUAL "")
                message(WARNING "KEEP_UPDATED argument is only used when the "
                        "BRANCH argument is passed.")
        endif ()

        if (ARGS_BRANCH AND ARGS_VERSION)
                message(WARNING "VERSION argument is only used when downloading "
                        "a release, not a specific branch.")
        endif ()

        if (ARGS_DOWNLOAD_ONLY AND ARGS_OPTIONS)
                message(WARNING "OPTIONS argument is only used when the DOWNLOAD_ONLY "
                        "argument is set to OFF.")
        endif ()

        if (ARGS_GIT_REPOSITORY AND NOT ARGS_BRANCH AND NOT ARGS_VERSION)
                message(WARNING "VERSION and BRANCH argument is missing, downloading "
                        "latest public release...")
        endif ()

        if (ARGS_FILE AND ARGS_INSTALL_ENABLED)
                message(WARNING "INSTALL_ENABLED argument is only used when the FILE "
                        "argument is set to OFF.")
        endif ()
endfunction ()

function (_get_latest_tag)
        set(ONE_VALUE_ARGS
                GIT_REPOSITORY
                LIBRARY_NAME
                CLEAR
                BRANCH
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY OR NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_get_latest_tag, please report this at "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories
        set(INTERNAL_LIBRARY_DIR "$ENV{INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
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
        set(GIT_COMMIT_COMMAND git log -n 1 "${ARGS_BRANCH}"
                --pretty=format:"%H")
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

        if (ARGS_BRANCH)
                execute_process(COMMAND ${GIT_COMMIT_COMMAND}
                        WORKING_DIRECTORY ${CACHE_DIR}
                        OUTPUT_VARIABLE COMMIT_HASH
                        OUTPUT_STRIP_TRAILING_WHITESPACE)

                if (ARGS_CLEAR)
                        file(REMOVE_RECURSE ${CACHE_DIR})
                endif ()

                set(${ARGS_OUTPUT_VARIABLE} ${COMMIT_HASH} PARENT_SCOPE)
                return()
        endif ()

        # Sort tags by creation date
        execute_process(
                COMMAND ${GIT_SORT_COMMAND}
                WORKING_DIRECTORY ${CACHE_DIR}
                RESULT_VARIABLE AA
                OUTPUT_VARIABLE TAG_LIST
                OUTPUT_STRIP_TRAILING_WHITESPACE)

        if (ARGS_CLEAR)
                file(REMOVE_RECURSE ${CACHE_DIR})
        endif ()

        if (NOT TAG_LIST)
                message(FATAL_ERROR "Failed to obtain tag list.")
        endif ()

        # Get the latest tag from the tag list
        string(REGEX MATCH "([^ \n]+)" TAG_NAME ${TAG_LIST})
        set(TAG_NAME "${CMAKE_MATCH_1}")

        set(${ARGS_OUTPUT_VARIABLE} ${TAG_NAME} PARENT_SCOPE)
endfunction ()

function (_get_current_version)
        set(ONE_VALUE_ARGS
                BRANCH
                DIRECTORY
                OUTPUT_FOUND
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        set(${OUTPUT_FOUND} OFF PARENT_SCOPE)

        if (NOT ARGS_BRANCH)
                set(GIT_COMMAND git describe --tags --exact-match)
        else ()
                set(GIT_COMMAND git rev-parse HEAD)
        endif ()

        execute_process(
                COMMAND ${GIT_COMMAND}
                ERROR_QUIET
                RESULT_VARIABLE RESULT
                OUTPUT_VARIABLE OUTPUT
                OUTPUT_STRIP_TRAILING_WHITESPACE
                WORKING_DIRECTORY "${ARGS_DIRECTORY}")

        if ("${RESULT}" EQUAL "0")
                set(${ARGS_OUTPUT_VARIABLE} "${OUTPUT}" PARENT_SCOPE)
                set(${ARGS_OUTPUT_FOUND} ON PARENT_SCOPE)
        endif ()
endfunction ()

function (_clear_if_necessary)
        set(ONE_VALUE_ARGS
                LIBRARY_NAME
                LIBRARY_DIR
                VERSION
                BRANCH
                OUTPUT_SHOULD_SKIP_DOWNLOAD)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        set(VERSION_CACHE_VARIABLE_NAME "GetProject_${ARGS_LIBRARY_NAME}_VERSION")

        # If the variable is not present, check if the library dir exists. If so
        # check the version, it may have been externally downloaded or by another
        # CMake configuration with a different build directory.
        if (NOT DEFINED ${VERSION_CACHE_VARIABLE_NAME} AND EXISTS ${ARGS_LIBRARY_DIR})
                _get_current_version(
                        BRANCH ${ARGS_BRANCH}
                        DIRECTORY ${ARGS_LIBRARY_DIR}
                        OUTPUT_FOUND VERSION_FOUND
                        OUTPUT_VARIABLE EXISTENT_VERSION)

                if (VERSION_FOUND)
                        set(${VERSION_CACHE_VARIABLE_NAME} ${EXISTENT_VERSION}
                                CACHE STRING "${ARGS_LIBRARY_NAME} version" FORCE)
                endif ()
        endif ()

        set(EXISTENT_VERSION "${${VERSION_CACHE_VARIABLE_NAME}}")
        set(NEW_VERSION      "${ARGS_VERSION}")

        # The above code did not find any version or for some reason the version
        # was saved as empty.
        if ("${EXISTENT_VERSION}" STREQUAL "")
                set(${OUTPUT_SHOULD_SKIP_DOWNLOAD} OFF PARENT_SCOPE)
                if (EXISTS ${ARGS_LIBRARY_DIR})
                        file(REMOVE_RECURSE ${ARGS_LIBRARY_DIR})
                endif ()
        elseif (ARGS_BRANCH)
                # Branches do not have versions, so we clear if the commit hash
                # differs.
                if (${NEW_VERSION} STREQUAL ${EXISTENT_VERSION})
                        return()
                endif ()

                set(${OUTPUT_SHOULD_SKIP_DOWNLOAD} OFF PARENT_SCOPE)
                if (EXISTS ${ARGS_LIBRARY_DIR})
                        file(REMOVE_RECURSE ${ARGS_LIBRARY_DIR})
                endif ()
        else ()
                _check_version_collisions(
                        EXISTENT_VERSION ${EXISTENT_VERSION}
                        NEW_VERSION ${NEW_VERSION}
                        OUTPUT_SHOULD_CLEAR SHOULD_CLEAR
                        OUTPUT_SHOULD_SKIP_DOWNLOAD SHOULD_SKIP_DOWNLOAD)

                _is_directory_empty(
                        LIBRARY_DIR ${ARGS_LIBRARY_DIR}
                        OUTPUT_VARIABLE LIBRARY_DIR_EMPTY)

                if (SHOULD_CLEAR OR LIBRARY_DIR_EMPTY)
                        set(${OUTPUT_SHOULD_SKIP_DOWNLOAD} OFF PARENT_SCOPE)
                        if (EXISTS ${ARGS_LIBRARY_DIR})
                                file(REMOVE_RECURSE ${ARGS_LIBRARY_DIR})
                        endif ()
                endif ()
        endif ()

        set(${VERSION_CACHE_VARIABLE_NAME} ${ARGS_VERSION} CACHE STRING "${ARGS_LIBRARY_NAME} version" FORCE)
endfunction ()

function (_download_file)
        set(ONE_VALUE_ARGS
                URL
                DIRECTORY
                HASH
                HASH_TYPE
                OUTPUT_HASH)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL OR NOT ARGS_DIRECTORY)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_download_file, please report this at "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Get archive name and extension
        get_filename_component(FILE_NAME ${ARGS_URL} NAME)

        set(FILE_PATH "${ARGS_DIRECTORY}/${FILE_NAME}")

        if (ARGS_HASH)
                # Check if HASH_TYPE parameter was given
                if (NOT ARGS_HASH_TYPE)
                        message(FATAL_ERROR "HASH_TYPE must be provided when "
                                "passing HASH parameter to "
                                "download_file_from_url.")
                endif ()

                # Download file with hash comparison
                file(DOWNLOAD ${ARGS_URL} ${FILE_PATH}
                        STATUS RESPONSE)
        else ()
                # Download file without hash comparison
                file(DOWNLOAD ${ARGS_URL} ${FILE_PATH}
                        STATUS RESPONSE)
        endif ()

        # Check if response is good
        if (NOT RESPONSE EQUAL 0)
                message(FATAL_ERROR "Failed to download file '${FILE_NAME}', "
                        "response: '${RESPONSE}'.")
        endif()

        file(MD5 ${FILE_PATH} NEW_HASH)
        set(${ARGS_OUTPUT_HASH} ${NEW_HASH} PARENT_SCOPE)
endfunction ()

function (_extract_archive)
        set(ONE_VALUE_ARGS
                LIBRARY_NAME)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        # Directories and files
        set(INTERNAL_LIBRARY_DIR "$ENV{INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(TMP_DIR "${INTERNAL_LIBRARY_DIR}/.tmp")
        set(LIBRARY_DIR "$ENV{GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")

        # Create temporary directory and extract archive there
        file(MAKE_DIRECTORY ${TMP_DIR})
        file(ARCHIVE_EXTRACT INPUT ${FILE_PATH} DESTINATION ${TMP_DIR})

        # Move the extracted content to library directory
        file(GLOB EXTRACTED_CONTENT "${TMP_DIR}/*/**")
        file(COPY ${EXTRACTED_CONTENT} DESTINATION ${LIBRARY_DIR})

        # Clean up the temporary directory
        file(REMOVE_RECURSE ${TMP_DIR})
endfunction ()

function (_is_directory_empty)
        set(ONE_VALUE_ARGS
                LIBRARY_DIR
                OUTPUT_VARIABLE)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_LIBRARY_DIR OR NOT ARGS_OUTPUT_VARIABLE)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_is_directory_empty, please report this at "
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

function (_check_version_collisions)
        set(ONE_VALUE_ARGS
                EXISTENT_VERSION
                NEW_VERSION
                OUTPUT_SHOULD_CLEAR
                OUTPUT_SHOULD_SKIP_DOWNLOAD)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        set(REGEX_VERSION "^v?(([0-9]+)(\\.([0-9]+))?(\\.([0-9]+))?)(-[a-zA-Z_0-9]+)?$")
        if (NOT ${NEW_VERSION} MATCHES ${REGEX_VERSION})
                message(WARNING "Could not get version from the tag '${NEW_VERSION}'.")
                set(${OUTPUT_SHOULD_CLEAR} ON PARENT_SCOPE)
                return()
        endif ()

        string(REGEX MATCH ${REGEX_VERSION} MATCH ${ARGS_EXISTENT_VERSION})
        set(EXISTENT_VERSION_FULL "${CMAKE_MATCH_1}${CMAKE_MATCH_7}")
        set(EXISTENT_VERSION ${CMAKE_MATCH_1})
        set(EXISTENT_MAJOR ${CMAKE_MATCH_2})
        set(EXISTENT_MINOR ${CMAKE_MATCH_4})
        set(EXISTENT_PATCH ${CMAKE_MATCH_6})

        string(REGEX MATCH ${REGEX_VERSION} MATCH ${ARGS_NEW_VERSION})
        set(NEW_VERSION_FULL "${CMAKE_MATCH_1}${CMAKE_MATCH_7}")
        set(NEW_VERSION ${CMAKE_MATCH_1})
        set(NEW_MAJOR ${CMAKE_MATCH_2})
        set(NEW_MINOR ${CMAKE_MATCH_4})
        set(NEW_PATCH ${CMAKE_MATCH_6})

        if ("${EXISTENT_VERSION}" VERSION_EQUAL "${NEW_VERSION}")
                set(${ARGS_OUTPUT_SHOULD_SKIP_DOWNLOAD} ON PARENT_SCOPE)
                return()
        endif ()

        if ("${EXISTENT_VERSION}" VERSION_GREATER "${NEW_VERSION}")
                if (NOT "${PREVIOUS_MAJOR}" STREQUAL "${CURRENT_MAJOR}")
                        message(WARNING "${ARGS_LIBRARY_NAME} requires the "
                                "version '${NEW_VERSION_FULL}', which is "
                                "older than the currently used one "
                                "(${EXISTENT_VERSION_FULL}) and is "
                                "missing a major update.")
                endif ()

                # If the already present version is greater
                # than the requested one, do nothing.
                set(${ARGS_OUTPUT_SHOULD_SKIP_DOWNLOAD} ON PARENT_SCOPE)
        else ()
                if (NOT "${PREVIOUS_MAJOR}" STREQUAL "${CURRENT_MAJOR}")
                        message(WARNING "${ARGS_LIBRARY_NAME} requires the "
                                "version '${NEW_VERSION_FULL}', which is "
                                "newer than the currently used one "
                                "(${EXISTENT_VERSION_FULL}), which is "
                                "missing a major update.")
                endif ()

                set(${ARGS_OUTPUT_SHOULD_CLEAR} ON PARENT_SCOPE)
        endif ()
endfunction ()

function (_download_library_url)
        set(ONE_VALUE_ARGS
                URL
                LIBRARY_NAME)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_URL OR NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_download_library_url, please report this at "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories and files
        set(INTERNAL_LIBRARY_DIR "$ENV{INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(CACHE_DIR "${INTERNAL_LIBRARY_DIR}/download_library")
        set(LIBRARY_DIR "$ENV{GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")
        set(HASH_VAR_NAME "GetProject_${ARGS_LIBRARY_NAME}_HASH")

        # Create library internal directory
        if (NOT EXISTS ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})
        endif ()

        # Download library archive
        _download_file(
                URL ${ARGS_URL}
                DIRECTORY ${CACHE_DIR}
                HASH ${${HASH_VAR_NAME}}
                HASH_TYPE "MD5"
                OUTPUT_HASH NEW_HASH)

        # Don't waste time extracting stuff again if hashes match
        if (DEFINED ${HASH_VAR_NAME} AND "${NEW_HASH}" STREQUAL "${${HASH_VAR_NAME}}")
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

        set(${HASH_VAR_NAME} ${NEW_HASH} CACHE STRING "${ARGS_LIBRARY_NAME} hash" FORCE)

        # Delete old extracted data
        if (EXISTS ${LIBRARY_DIR})
                file(REMOVE_RECURSE ${LIBRARY_DIR})
        endif ()

        _extract_archive(
                LIBRARY_NAME ${ARGS_LIBRARY_NAME})
endfunction ()

function (_validate_git_repo)
        set(ONE_VALUE_ARGS
                GIT_REPOSITORY
                OUTPUT_VALID)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "" ${ARGN})

        if (NOT ARGS_GIT_REPOSITORY)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_validate_git_repo, please report this at "
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
                set(${ARGS_OUTPUT_VALID} OFF PARENT_SCOPE)
        else ()
                set(${ARGS_OUTPUT_VALID} ON PARENT_SCOPE)
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
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_download_library_git, please report this at "
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

        execute_process(
                COMMAND ${GIT_CLONE_COMMAND}
                OUTPUT_QUIET
                ERROR_QUIET)
endfunction ()

function (_add_subdirectory)
        set(ONE_VALUE_ARGS
                LIBRARY_NAME
                INSTALL_ENABLED)
        set(MULTI_VALUE_ARGS
                OPTIONS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (NOT ARGS_LIBRARY_NAME)
                message(FATAL_ERROR "Missing parameters in function call to "
                        "_add_subdirectory, please report this at "
                        "https://github.com/Storterald/GetProject/issues.")
        endif ()

        # Directories
        set(INTERNAL_LIBRARY_DIR "$ENV{INTERNAL_GET_PROJECT_DIR}/${ARGS_LIBRARY_NAME}")
        set(LIBRARY_DIR "$ENV{GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")

        if (NOT EXISTS ${INTERNAL_LIBRARY_DIR})
                file(MAKE_DIRECTORY ${INTERNAL_LIBRARY_DIR})
        endif ()

        # If the library does not have CMake support. The inclusion must
        # be handled by the user.
        if (NOT EXISTS "${LIBRARY_DIR}/CMakeLists.txt")
                message(WARNING "CMakeLists.txt file not found in library "
                        "'${ARGS_LIBRARY_NAME}'. Not adding as a "
                        "subdirectory.")
                return()
        endif ()

        # Define variables for external use.
        set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)

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

        add_subdirectory(${LIBRARY_DIR} ${INTERNAL_LIBRARY_DIR} EXCLUDE_FROM_ALL)

        # To install a directory it's required that the library is built.
        # TODO find something better
        if (ARGS_INSTALL_ENABLED)
                message(STATUS "GetProject: Installing ${ARGS_LIBRARY_NAME}...")
                set(BUILD_DIR "${LIBRARY_DIR}/build/")

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

                execute_process(COMMAND ${CMAKE_COMMAND} . ${CONFIG_ARGS}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                execute_process(COMMAND ${CMAKE_COMMAND} ${BUILD_COMMAND}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                execute_process(COMMAND ${CMAKE_COMMAND} ${INSTALL_COMMAND}
                        OUTPUT_QUIET
                        WORKING_DIRECTORY ${LIBRARY_DIR})

                file(REMOVE_RECURSE ${BUILD_DIR})
                message(STATUS "GetProject: ${ARGS_LIBRARY_NAME} installed.")
        endif ()
endfunction ()

# ----------------------------------------------------------------------------------------------------------------------
# END-USER FUNCTIONS
# ----------------------------------------------------------------------------------------------------------------------

function (get_project)
        set(ONE_VALUE_ARGS
                URL
                GIT_REPOSITORY
                FILE
                LIBRARY_NAME
                INSTALL_ENABLED
                DOWNLOAD_ONLY
                BRANCH
                KEEP_UPDATED
                VERSION)
        set(MULTI_VALUE_ARGS
                OPTIONS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        if (ARGS_GIT_REPOSITORY)
                find_package(Git)
                if (NOT GIT_FOUND)
                        message(FATAL_ERROR "Git is required to use GetProject "
                                "with the GIT_REPOSITORY parameter. "
                                "You can download git at "
                                "https://git-scm.com/downloads")
                endif ()
        endif ()

        _validate_args(${ARGV})

        if (ARGS_FILE)
                set(ARGS_DOWNLOAD_ONLY ON)
        endif ()

        # If the library is downloaded via git, validate the repo and get the name.
        if (ARGS_GIT_REPOSITORY)
                # If connected to the internet validate the git repository
                # without cloning
                _validate_git_repo(
                        GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                        OUTPUT_VALID REPO_VALID)

                if (NOT REPO_VALID)
                        message(WARNING "Invalid or inaccessible git repository "
                                "'${ARGS_GIT_REPOSITORY}'. Not downloading.")

                        # Even if the repo is invalid, if the directory already
                        # exists, add it.
                        if (NOT ARGS_DOWNLOAD_ONLY)
                                _add_subdirectory(
                                        LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                                        INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                                        OPTIONS ${ARGS_OPTIONS})

                                set(${ARGS_LIBRARY_NAME}_SOURCE ${LIBRARY_DIR} PARENT_SCOPE)
                                set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)
                        endif ()

                        return()
                endif ()

                # Extract the library name from the GIT_REPOSITORY parameter and
                # save it in ARGS_LIBRARY_NAME if the user didn't provide one.
                if (NOT ARGS_LIBRARY_NAME)
                        string(REGEX REPLACE ".*/([^/]+)\\.git$" "\\1"
                                ARGS_LIBRARY_NAME ${ARGS_GIT_REPOSITORY})
                endif ()
        endif ()

        # Directories and files
        set(LIBRARY_DIR "$ENV{GET_PROJECT_OUTPUT_DIR}/${ARGS_LIBRARY_NAME}")

        if (ARGS_GIT_REPOSITORY)
                # Check if the given version is set as null or latest, if
                # so fetch the latest release.
                string(TOUPPER "${ARGS_VERSION}" CAPS_VERSION)
                if (ARGS_BRANCH OR NOT ARGS_VERSION OR "${CAPS_VERSION}" STREQUAL "LATEST")
                        _get_latest_tag(
                                GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                                CLEAR OFF
                                BRANCH ${ARGS_BRANCH}
                                OUTPUT_VARIABLE ARGS_VERSION)
                endif ()
        endif ()

        message(STATUS "GetProject: Adding '${ARGS_LIBRARY_NAME}'.")

        if (ARGS_GIT_REPOSITORY)
                _clear_if_necessary(
                        LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                        LIBRARY_DIR ${LIBRARY_DIR}
                        VERSION ${ARGS_VERSION}
                        BRANCH ${ARGS_BRANCH})
        endif ()

        if (ARGS_FILE)
                set(HASH_VAR_NAME "GetProject_${ARGS_LIBRARY_NAME}_HASH")
                _download_file(
                        URL ${ARGS_URL}
                        DIRECTORY ${LIBRARY_DIR}
                        HASH ${${HASH_VAR_NAME}}
                        HASH_TYPE "MD5"
                        OUTPUT_HASH NEW_HASH)

                set(${HASH_VAR_NAME} ${NEW_HASH} CACHE STRING "${ARGS_LIBRARY_NAME} hash" FORCE)
        elseif (ARGS_URL)
                _download_library_url(
                        URL ${ARGS_URL}
                        LIBRARY_NAME ${ARGS_LIBRARY_NAME})
        elseif (ARGS_GIT_REPOSITORY AND NOT SHOULD_SKIP_DOWNLOAD)
                _download_library_git(
                        GIT_REPOSITORY ${ARGS_GIT_REPOSITORY}
                        LIBRARY_DIR ${LIBRARY_DIR}
                        VERSION ${ARGS_VERSION}
                        BRANCH ${ARGS_BRANCH}
                        KEEP_UPDATED ${ARGS_KEEP_UPDATED})
        endif ()

        set(${ARGS_LIBRARY_NAME}_DOWNLOADED ON PARENT_SCOPE)
        set(${ARGS_LIBRARY_NAME}_SOURCE ${LIBRARY_DIR} PARENT_SCOPE)

        if (ARGS_DOWNLOAD_ONLY)
                return()
        endif ()

        _add_subdirectory(
                LIBRARY_NAME ${ARGS_LIBRARY_NAME}
                INSTALL_ENABLED ${ARGS_INSTALL_ENABLED}
                OPTIONS ${ARGS_OPTIONS})

        set(${ARGS_LIBRARY_NAME}_ADDED ON PARENT_SCOPE)
endfunction ()
