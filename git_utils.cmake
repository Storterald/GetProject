cmake_minimum_required(VERSION 3.5)

function(get_latest_tag)
        # Parse args
        set(ONE_VALUE_ARGS PROFILE_NAME REPOSITORY_NAME OUTPUT_VARIABLE)
        set(MULTI_VALUE_ARGS)
        cmake_parse_arguments(ARGS "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

        # Get github url from profile and repo name
        set(GITHUB_URL "https://github.com/${ARGS_PROFILE_NAME}/${ARGS_REPOSITORY_NAME}")

        # Temporary directory name
        set(TMP_DIR tmp_${ARGS_REPOSITORY_NAME})

        # Clone repo with lowest depth possible
        execute_process(
                COMMAND git clone --depth 1 --no-checkout ${GITHUB_URL} ${TMP_DIR}
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        )

        # Fetch all tags
        execute_process(
                COMMAND git fetch --tags --depth 1
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/${TMP_DIR}"
        )

        # Sort tags by creation date
        execute_process(
                COMMAND git for-each-ref --sort=-creatordate --format "%(refname:short)" refs/tags
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/${TMP_DIR}"
                OUTPUT_VARIABLE TAG_LIST
                OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        # Delete downloaded content
        file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/${TMP_DIR}")

        # Checking if tag list was obtained correctly
        if (NOT TAG_LIST)
                message(FATAL_ERROR "Failed to obtain tag list.")
        endif ()
        message(STATUS ${TAG_LIST})

        # Get the latest tag from the tag list
        string(REGEX MATCH "([^ \n]+)" TAG_NAME ${TAG_LIST})
        set(TAG_NAME "${CMAKE_MATCH_1}")

        message(STATUS "Latest tag for repository '${ARGS_REPOSITORY_NAME}' has been found to be '${TAG_NAME}'.")

        set(${ARGS_OUTPUT_VARIABLE} ${TAG_NAME} PARENT_SCOPE)
endfunction()