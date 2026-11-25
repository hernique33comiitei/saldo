find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Test Network)
include(ECMAddTests)

ecm_add_test(coretest.cpp
    TEST_NAME coretest
    LINK_LIBRARIES saldocore Qt6::Test Qt6::Sql KF6::I18n)

target_compile_definitions(coretest PRIVATE FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

ecm_add_test(pluggyclienttest.cpp
    TEST_NAME pluggyclienttest
    LINK_LIBRARIES saldocore Qt6::Test Qt6::Network)

# Pages and components use the design system (org.saldo.ui), never the
# controls it wraps (see tools/check-ui.sh and CLAUDE.md, "Design system").
add_test(NAME check-ui COMMAND ${CMAKE_SOURCE_DIR}/tools/check-ui.sh --strict)
