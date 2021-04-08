cmake_minimum_required(VERSION 3.12.3)

project(Minizip LANGUAGES C)
file(TO_CMAKE_PATH ${zlib_DIR} zlib_DIR)

include_directories(include)
add_library(Minizip STATIC zip.c unzip.c ioapi.c)

target_include_directories(Minizip 
  PRIVATE
    ${zlib_DIR}/include
)
target_link_directories(Minizip PRIVATE ${zlib_DIR}/lib)

set_target_properties(Minizip PROPERTIES
  COMPILE_PDB_OUTPUT_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib
  COMPILE_PDB_NAME Minizip
)

install(TARGETS Minizip
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)

file(GLOB include_files include/*)
install(FILES ${include_files} DESTINATION include)
install(FILES module/module.modulemap DESTINATION include)
  
file(GLOB zlib_include_files ${zlib_DIR}/include/*)
install(FILES ${zlib_include_files} DESTINATION include)
install(FILES ${zlib_DIR}/lib64/zlib.dll DESTINATION bin)
install(FILES ${zlib_DIR}/lib64/zlib.pdb DESTINATION bin)
install(FILES ${zlib_DIR}/lib64/zlib.lib DESTINATION lib)
install(FILES ${zlib_DIR}/lib64/zlib.exp DESTINATION lib)
