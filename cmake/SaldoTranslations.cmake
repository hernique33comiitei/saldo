# Compiles po/<lang>.po into <lang>/LC_MESSAGES/<domain>.mo with msgfmt and
# installs them into KDE_INSTALL_LOCALEDIR.
#
#   saldo_install_translations(DOMAIN <domain> PO_DIR <dir>)

find_program(MSGFMT_EXECUTABLE msgfmt)

function(saldo_install_translations)
    cmake_parse_arguments(ARG "" "DOMAIN;PO_DIR" "" ${ARGN})

    if(NOT MSGFMT_EXECUTABLE)
        message(WARNING "msgfmt not found: translations will not be built (install gettext)")
        return()
    endif()

    file(GLOB _po_files "${ARG_PO_DIR}/*.po")
    set(_mo_files)
    foreach(_po ${_po_files})
        get_filename_component(_lang ${_po} NAME_WE)
        set(_mo_dir "${CMAKE_CURRENT_BINARY_DIR}/locale/${_lang}/LC_MESSAGES")
        set(_mo "${_mo_dir}/${ARG_DOMAIN}.mo")
        add_custom_command(
            OUTPUT ${_mo}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_mo_dir}
            COMMAND ${MSGFMT_EXECUTABLE} --check -o ${_mo} ${_po}
            DEPENDS ${_po}
            COMMENT "Compiling ${_lang} translation"
            VERBATIM)
        install(FILES ${_mo} DESTINATION ${KDE_INSTALL_LOCALEDIR}/${_lang}/LC_MESSAGES)
        list(APPEND _mo_files ${_mo})
    endforeach()

    add_custom_target(${ARG_DOMAIN}-translations ALL DEPENDS ${_mo_files})
endfunction()
