cmake_minimum_required(VERSION 3.5)

# Gets the last published tag of a repository
function(get_latest_tag)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME CLEAR OUTPUT_VARIABLE)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Validate parameters
        if (NOT ARGS_PROFILE_NAME)
                message(FATAL_ERROR "PROFILE_NAME is a mandatory parameter of get_latest_tag.")
        endif ()
        if (NOT ARGS_REPOSITORY_NAME)
                message(FATAL_ERROR "REPOSITORY_NAME is a mandatory parameter of get_latest_tag.")
        endif ()

        # Constants
        set(GIT_UTILS_DIR "${CMAKE_BINARY_DIR}/git_utils")
        set(CACHE_DIR "${GIT_UTILS_DIR}/${ARGS_REPOSITORY_NAME}")
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}.git")

        # Create git_utils internal directory
        if (NOT EXISTS ${GIT_UTILS_DIR})
                file(MAKE_DIRECTORY ${GIT_UTILS_DIR})
        endif ()

        # False if CLEAR was false in a previous call.
        if (NOT EXISTS ${CACHE_DIR})
                file(MAKE_DIRECTORY ${CACHE_DIR})

                # Clone repo with lowest depth possible
                execute_process(
                        COMMAND git clone --depth 1 --no-checkout ${GITHUB_URL} "."
                        WORKING_DIRECTORY ${CACHE_DIR}
                )

                # Fetch tags
                execute_process(
                        COMMAND git fetch --tags --depth 1
                        WORKING_DIRECTORY ${CACHE_DIR}
                )
        else ()
                message(STATUS "git_utils::get_latest_tag() cached directory for repository '${ARGS_REPOSITORY_NAME}' "
                        "already exists, not fetching.")
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

        message(STATUS "Latest tag for repository '${ARGS_REPOSITORY_NAME}' has been found to be '${TAG_NAME}'.")

        set(${ARGS_OUTPUT_VARIABLE} ${TAG_NAME} PARENT_SCOPE)
endfunction()