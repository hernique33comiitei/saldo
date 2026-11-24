# Compiles po/<lang>.po into <lang>/LC_MESSAGES/<domain>.mo with msgfmt and
# installs them into KDE_INSTALL_LOCALEDIR.
#
#   saldo_install_translations(DOMAIN <domain> PO_DIR <dir>)

find_program(MSGFMT_EXECUTABLE msgfmt)
if(ANDROID)
    # split_plurals.py: plural entries as plain ones for libintl-lite.
    find_program(SALDO_PYTHON3_EXECUTABLE python3)
endif()

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
        # Android's gettext (libintl-lite, from Craft) has no plural forms: every
        # i18np() came out in English. Its catalog gets them as plain entries.
        set(_source_po ${_po})
        if(ANDROID)
            if(NOT SALDO_PYTHON3_EXECUTABLE)
                message(FATAL_ERROR "python3 is needed to build Android translations (cmake/split_plurals.py)")
            endif()
            set(_source_po "${CMAKE_CURRENT_BINARY_DIR}/po-android/${_lang}.po")
            add_custom_command(
                OUTPUT ${_source_po}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/po-android
                COMMAND ${SALDO_PYTHON3_EXECUTABLE} ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/split_plurals.py ${_po} ${_source_po}
                DEPENDS ${_po} ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/split_plurals.py
                COMMENT "Splitting ${_lang} plurals for Android"
                VERBATIM)
        endif()
        add_custom_command(
            OUTPUT ${_mo}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${_mo_dir}
            COMMAND ${MSGFMT_EXECUTABLE} --check -o ${_mo} ${_source_po}
            DEPENDS ${_source_po}
            COMMENT "Compiling ${_lang} translation"
            VERBATIM)
        install(FILES ${_mo} DESTINATION ${KDE_INSTALL_LOCALEDIR}/${_lang}/LC_MESSAGES)
        list(APPEND _mo_files ${_mo})
    endforeach()

    add_custom_target(${ARG_DOMAIN}-translations ALL DEPENDS ${_mo_files})
endfunction()
