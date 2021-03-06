# this module look for lapack/blas and other numerical library support
# it will define the following values
# Since lapack and blas are essential, link_liraries are called.
# 1) search ENV MKL 
# 2) search MKL in usual paths
# 3) search ENV ATLAS
# 4) search lapack/blas
# 5) give up

set(LAPACK_FOUND FALSE)
set(BLAS_FOUND FALSE)
set(MKL_FOUND FALSE)
#
#IF(NOT CMAKE_COMPILER_IS_GNUCXX)
  if($ENV{MKL_HOME} MATCHES "mkl")
    if(NOT MKL_FOUND)
      #default MKL libraries 
      set(mkl_libs "mkl_lapack;mkl;guide")
      STRING(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" MKL_VERSION "$ENV{MKL_HOME}")

      #     if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64")
        SET(MKLPATH $ENV{MKL_HOME}/lib/em64t)
        if(${MKL_VERSION} MATCHES "10\\.2\\.[0-4]")
          set(mkl_libs "mkl_intel_lp64;mkl_sequential;mkl_core;mkl_solver_lp64_sequential")
        else(${MKL_VERSION} MATCHES "10\\.2\\.[0-4]")
          SET(MKLPATH $ENV{MKL_HOME}/lib/intel64)
          set(mkl_libs "-L$ENV{MKL_HOME};mkl_intel_lp64;mkl_sequential;mkl_core")
          message(STATUS "MKLPATH=${MKLPATH}")
        endif(${MKL_VERSION} MATCHES "10\\.2\\.[0-4]")
        # endif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64")

      if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "i386")
        SET(MKLPATH $ENV{MKL_HOME}/lib/32)
      endif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "i386")

      if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "ia64")
        SET(MKLPATH $ENV{MKL_HOME}/lib/64)
      endif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "ia64")

      SET(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -L${MKLPATH}")

      if(${MKL_VERSION} MATCHES "10\\.0\\.[0-2]")
        link_libraries(-L${MKLPATH}/lib/intel64 ${MKLPATH}/libmkl_lapack.a -lmkl -lguide)
      else(${MKL_VERSION} MATCHES "10\\.0\\.[0-2]")
        foreach(alib ${mkl_libs})
          link_libraries(${alib})
        endforeach()
      endif(${MKL_VERSION} MATCHES "10\\.0\\.[0-2]")

      set(LAPACK_FOUND TRUE)
      set(BLAS_FOUND TRUE)
      set(MKL_FOUND TRUE)

      FIND_PATH(MKL_INCLUDE_DIR mkl.h $ENV{MKL_HOME}/include)
      if(MKL_INCLUDE_DIR)
        MESSAGE(STATUS "MKL_INCLUDE_DIR=${MKL_INCLUDE_DIR}")
        INCLUDE_DIRECTORIES(${MKL_INCLUDE_DIR})
        set(HAVE_MKL TRUE)
        find_file(mkl_vml_file mkl_vml.h $ENV{MKL_HOME}/include)
        if(mkl_vml_file)
          set(HAVE_MKL_VML TRUE)
        endif(mkl_vml_file)
      endif(MKL_INCLUDE_DIR)
    endif(NOT MKL_FOUND)
  else($ENV{MKL_HOME} MATCHES "mkl")
    IF($ENV{MKL} MATCHES "mkl")
      MESSAGE(STATUS "Using intel/mkl library: $ENV{MKL}")
      link_libraries($ENV{MKL})
      set(LAPACK_FOUND TRUE)
      set(BLAS_FOUND TRUE)
      set(MKL_FOUND TRUE)
    ENDIF($ENV{MKL} MATCHES "mkl")
  endif($ENV{MKL_HOME} MATCHES "mkl")


  #ENDIF(NOT CMAKE_COMPILER_IS_GNUCXX)

if(MKL_FOUND)
  FIND_PATH(MKL_INCLUDE_DIR mkl.h $ENV{MKL_HOME}/include)
  if(MKL_INCLUDE_DIR)
    MESSAGE(STATUS "MKL_INCLUDE_DIR=${MKL_INCLUDE_DIR}")
    INCLUDE_DIRECTORIES(${MKL_INCLUDE_DIR})
    set(HAVE_MKL TRUE)
    find_file(mkl_vml_file mkl_vml.h $ENV{MKL_HOME}/include)
    if(mkl_vml_file)
      set(HAVE_MKL_VML TRUE)
    endif(mkl_vml_file)
  endif(MKL_INCLUDE_DIR)
  MESSAGE(STATUS "MKL libraries are found")
  set(LAPACK_FOUND TRUE)
  set(BLAS_FOUND TRUE)
else(MKL_FOUND)
  if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    SET(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -framework vecLib")
    SET(LAPACK_LIBRARY_INIT 1 CACHE BOOL "use Mac Framework")
    SET(MAC_VECLIB 1 CACHE BOOL "use Mac Framework")
    MESSAGE(STATUS "Using Framework on Darwin.")
    set(LAPACK_FOUND TRUE)
    set(BLAS_FOUND TRUE)
  endif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

  if(${CMAKE_SYSTEM_NAME} MATCHES "AIX")
    link_libraries(-lessl -lmass -lmassv)
    set(BLAS_FOUND TRUE)
  endif(${CMAKE_SYSTEM_NAME} MATCHES "AIX")

  if($ENV{LAPACK} MATCHES "lapack")
    link_libraries($ENV{LAPACK})
    set(LAPACK_FOUND TRUE)
  endif($ENV{LAPACK} MATCHES "lapack")

  IF($ENV{ATLAS_HOME} MATCHES "atlas")
    # COULD SEARCH THESE but..... 
    set(atlas_libs "lapack;f77blas;cblas;atlas")
    IF(QMC_BUILD_STATIC)
      SET(lapack_libs "liblapack.a")
      SET(f77blas_libs "libf77blas.a")
      SET(cblas_libs "libcblas.a")
      SET(atlas_libs "libatlas.a")
      FIND_LIBRARY(LAPACK_LIBRARIES ${lapack_libs} $ENV{ATLAS_HOME}/lib)
      FIND_LIBRARY(F77BLAS_LIBRARIES ${f77blas_libs} $ENV{ATLAS_HOME}/lib)
      FIND_LIBRARY(CBLAS_LIBRARIES ${cblas_libs} $ENV{ATLAS_HOME}/lib)
      FIND_LIBRARY(ATLAS_LIBRARIES ${atlas_libs} $ENV{ATLAS_HOME}/lib)
      MESSAGE(STATUS "LAPACK Libraries:" ${LAPACK_LIBRARIES})
      MESSAGE(STATUS "F77BLAS Libraries:" ${F77BLAS_LIBRARIES})
      MESSAGE(STATUS "CBLAS Libraries:" ${CBLAS_LIBRARIES})
      MESSAGE(STATUS "ATLAS Libraries:" ${ATLAS_LIBRARIES})
      link_libraries(${LAPACK_LIBRARIES})
      link_libraries(${F77BLAS_LIBRARIES})
      link_libraries(${CBLAS_LIBRARIES})
      link_libraries(${ATLAS_LIBRARIES})
    ELSE(QMC_BUILD_STATIC)
      link_libraries($ENV{ATLAS_HOME})
    ENDIF(QMC_BUILD_STATIC)
    set(LAPACK_FOUND TRUE)
    set(BLAS_FOUND TRUE)
  ELSE($ENV{ATLAS_HOME} MATCHES "atlas")
    IF($ENV{ACML_HOME} MATCHES "acml")
      SET(ACML_LIBRARIES $ENV{ACML_HOME}/lib/libacml.a)
      link_libraries(${ACML_LIBRARIES})
      MESSAGE(STATUS "ACML LIBRARIES=" ${ACML_LIBRARIES})
      set(LAPACK_FOUND TRUE)
      set(BLAS_FOUND TRUE)
    ENDIF($ENV{ACML_HOME} MATCHES "acml")
  ENDIF($ENV{ATLAS_HOME} MATCHES "atlas")


endif(MKL_FOUND)

if(LAPACK_FOUND AND BLAS_FOUND)
  MESSAGE(STATUS "LAPACK and BLAS libraries are linked to all the applications")
else(LAPACK_FOUND AND BLAS_FOUND)
  MESSAGE(STATUS "Could not find LAPACK and/or BLAS, specify MKL_HOME, ATLAS_HOME, ACML_HOME")
  find_library(LAPACK_LIBRARIES lapack)
  find_library(BLAS_LIBRARIES blas)
  if(LAPACK_LIBRARIES AND BLAS_LIBRARIES)
    link_libraries(${LAPACK_LIBRARIES} ${BLAS_LIBRARIES})
    MESSAGE("Found LAPACK, BLAS, ATLAS libraries.")
    MESSAGE("LAPACK Libraries:" ${LAPACK_LIBRARIES})
    MESSAGE("BLAS Libraries:" ${BLAS_LIBRARIES})
    set(LAPACK_FOUND TRUE)
    set(BLAS_FOUND TRUE)
  else(LAPACK_LIBRARIES AND BLAS_LIBRARIES)
    MESSAGE("Failed to link LAPACK, BLAS, ATLAS libraries.")
  endif(LAPACK_LIBRARIES AND BLAS_LIBRARIES)
  find_path(LAPACK_INCLUDE_DIRS lapack)
  find_path(BLAS_INCLUDE_DIRS blas)
  if(LAPACK_INCLUDE_DIRS AND BLAS_INCLUDE_DIRS)
    INCLUDE_DIRECTORIES(${LAPACK_INCLUDE_DIRS} ${BLAS_INCLUDE_DIRS})
    set(LAPACK_FOUND TRUE)
    set(BLAS_FOUND TRUE)
  else(LAPACK_INCLUDE_DIRS AND BLAS_INCLUDE_DIRS)
    MESSAGE("Failed to find LAPACK, BLAS, ATLAS include dirs.")
  endif(LAPACK_INCLUDE_DIRS AND BLAS_INCLUDE_DIRS)
endif(LAPACK_FOUND AND BLAS_FOUND)

#MARK_AS_ADVANCED(
#  LAPACK_LIBRARIES 
#  BLAS_LIBRARIES 
#  )
#IF(USE_SCALAPACK)
#  SET(PNPATHS 
#    ${MKL_PATHS}
#    ${BLACS_HOME}/lib
#    ${SCALAPACK_HOME}/lib
#    /usr/lib
#    /opt/lib
#    /usr/local/lib
#    /sw/lib
#    )
#
#  IF(INTEL_MKL)
#    FIND_LIBRARY(BLACSLIB mkl_blacs_${PLAT}_lp${QMC_BITS} PATHS  ${PNPATHS})
#    FIND_LIBRARY(SCALAPACKLIB mkl_scalapack PATHS  ${PNPATHS})
#  ENDIF(INTEL_MKL)
#
#  IF(NOT SCALAPACKLIB)
#    FIND_LIBRARY(BLACSLIB blacs_MPI-${PLAT}-{BLACSDBGLVL} PATHS  ${PNPATHS})
#    FIND_LIBRARY(BLACSCINIT blacsCinit_MPI-${PLAT}-{BLACSDBGLVL} PATHS  ${PNPATHS})
#    FIND_LIBRARY(SCALAPACKLIB scalapack PATHS  ${PNPATHS})
#  ENDIF(NOT SCALAPACKLIB)
#
#  IF(BLACSLIB AND SCALAPACKLIB)
#    SET(FOUND_SCALAPACK 1 CACHE BOOL "Found scalapack library")
#  ELSE(BLACSLIB AND SCALAPACKLIB)
#    SET(FOUND_SCALAPACK 0 CACHE BOOL "Mising scalapack library")
#  ENDIF(BLACSLIB AND SCALAPACKLIB)
#
#  MARK_AS_ADVANCED(
#    BLACSCINIT
#    BLACSLIB
#    SCALAPACKLIB
#    FOUND_SCALAPACK
#    )
#ENDIF(USE_SCALAPACK)

