cmake_minimum_required(VERSION 3.28)

project(Q16TOOLS VERSION 1.0 DESCRIPTION "Toolkit for Q16 file format")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

find_library(MATH_LIBRARY m)	# stb_image needs libm on Unix-like systems. Not found (or needed) on Windows.

add_executable(gen_q16
	gen_q16.c
	q16_lib.c
)

target_link_libraries(gen_q16
	PRIVATE $<$<BOOL:${MATH_LIBRARY}>:${MATH_LIBRARY}>
)

add_executable(q16totga
	dec_q16.c
	q16_lib.c
)

target_link_libraries(q16totga
	PRIVATE $<$<BOOL:${MATH_LIBRARY}>:${MATH_LIBRARY}>
)

add_executable(q16bench
	q16bench.c
	q16_lib.c
)

add_executable(gen_deltatab
	gen_deltatab.c
)

add_executable(q16info
	q16info.c
	q16_lib.c
)

target_link_libraries(q16bench
	PRIVATE $<$<BOOL:${MATH_LIBRARY}>:${MATH_LIBRARY}>
)
