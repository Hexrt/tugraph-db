cmake_minimum_required(VERSION 3.1)

# boost
set(Boost_USE_STATIC_LIBS ON)
find_package(Boost 1.68 REQUIRED COMPONENTS system filesystem)

# threads
find_package(Threads REQUIRED)

if (ENABLE_FULLTEXT_INDEX)
    # jni
    if(APPLE)
        SET(JAVA_INCLUDE_PATH "$ENV{JAVA_INCLUDE_PATH}")
    endif()
    find_package(JNI REQUIRED)
endif ()

# generate version info
include(cmake/GenerateVersionInfo.cmake)
GenerateVersionInfo(${LGRAPH_VERSION_MAJOR} ${LGRAPH_VERSION_MINOR} ${LGRAPH_VERSION_PATCH}
        ${CMAKE_CURRENT_LIST_DIR}/core/version.h.in
        ${CMAKE_CURRENT_LIST_DIR}/core/version.h)

# protbuf
include(cmake/GenerateProtobuf.cmake)
GenerateProtobufCpp(${CMAKE_CURRENT_LIST_DIR}/protobuf
        PROTO_SRCS PROTO_HEADERS
        ${CMAKE_CURRENT_LIST_DIR}/protobuf/ha.proto)

set(LGRAPH_CORE_SRC
        core/audit_logger.cpp
        core/data_type.cpp
        core/edge_index.cpp
        core/field_extractor.cpp
        core/full_text_index.cpp
        core/global_config.cpp
        core/graph.cpp
        core/graph_edge_iterator.cpp
        core/graph_vertex_iterator.cpp
        core/index_manager.cpp
        core/iterator_base.cpp
        core/kv_store_iterator.cpp
        core/kv_store_mdb.cpp
        core/kv_store_table.cpp
        core/kv_store_transaction.cpp
        core/kv_table_comparators.cpp
        core/lgraph_date_time.cpp
        core/lightning_graph.cpp
        core/schema.cpp
        core/sync_file.cpp
        core/thread_id.cpp
        core/transaction.cpp
        core/vertex_index.cpp
        core/wal.cpp
        core/lmdb/mdb.c
        core/lmdb/midl.c)

set(LGRAPH_DB_SRC
        db/acl.cpp
        db/db.cpp
        db/galaxy.cpp
        db/graph_manager.cpp
        db/token_manager.cpp)

set(LGRAPH_ALGO_SRC
        algo/algo.cpp)

set(LGRAPH_API_SRC
        lgraph_api/lgraph_db.cpp
        lgraph_api/lgraph_edge_iterator.cpp
        lgraph_api/lgraph_galaxy.cpp
        lgraph_api/lgraph_graph.cpp
        lgraph_api/lgraph_vertex_index_iterator.cpp
        lgraph_api/lgraph_edge_index_iterator.cpp
        lgraph_api/lgraph_traversal.cpp
        lgraph_api/lgraph_txn.cpp
        lgraph_api/lgraph_utils.cpp
        lgraph_api/lgraph_vertex_iterator.cpp
        lgraph_api/lgraph_result.cpp
        lgraph_api/result_element.cpp)

add_library(lgraph SHARED
        ${LGRAPH_API_SRC}
        ${LGRAPH_CORE_SRC}
        ${LGRAPH_DB_SRC}
        ${LGRAPH_ALGO_SRC}

        plugin/cpp_plugin.cpp
        plugin/plugin_context.cpp
        plugin/plugin_manager.cpp
        plugin/python_plugin.cpp

        ${DEPS_INCLUDE_DIR}/tiny-process-library/process.cpp
        ${DEPS_INCLUDE_DIR}/tiny-process-library/process_unix.cpp
        ${PROTO_SRCS})

target_include_directories(lgraph PUBLIC
        ${DEPS_LOCAL_INCLUDE_DIR}
        ${DEPS_INCLUDE_DIR}
        ${LGRAPH_INCLUDE_DIR}
        ${LGRAPH_SRC_DIR}
        ${LGRAPH_SRC_DIR}/cypher
        ${JNI_INCLUDE_DIRS})

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_link_libraries(lgraph PUBLIC
            rt
            gomp
            pthread
            -Wl,-Bstatic
            ${Boost_LIBRARIES}
            -static-libstdc++
            -static-libgcc
            -Wl,-Bdynamic
            stdc++fs
            stdc++
            crypto
            -Wl,--whole-archive
            ${PROTOBUF_LIBRARY}
            -Wl,--no-whole-archive
            ${JAVA_JVM_LIBRARY}
            z)
elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        target_link_libraries(lgraph PUBLIC
                boost_system
                boost_filesystem
                omp
                pthread
                crypto
                ${PROTOBUF_LIBRARY}
                ${JAVA_JVM_LIBRARY})
    else ()
        target_link_libraries(lgraph PUBLIC
                rt
                omp
                pthread
                -Wl,-Bstatic
                ${Boost_LIBRARIES}
                -Wl,-Bdynamic
                c++experimental
                c++fs
                crypto
                -Wl,--whole-archive
                ${PROTOBUF_LIBRARY}
                -Wl,--no-whole-archive
                ${JAVA_JVM_LIBRARY}
                z)
    endif ()
endif ()

if (ENABLE_SQL_IO)
    find_library(ODBC_LIBRARIES NAMES odbc)
    if (ODBC_LIBRARIES_NOT_FOUND)
        message(FATAL_ERROR "ODBC enabled, but unable to find ODBC library.")
    endif (ODBC_LIBRARIES_NOT_FOUND)
    target_sources(lgraph PRIVATE ${DEPS_INCLUDE_DIR}/fma-common/sql_stream.cpp)
    target_link_libraries(lgraph PUBLIC odbc)
endif (ENABLE_SQL_IO)

set_target_properties(lgraph PROPERTIES OUTPUT_NAME "lgraph")
target_compile_definitions(lgraph PUBLIC -DBOOST_STACKTRACE_USE_ADDR2LINE=1)
