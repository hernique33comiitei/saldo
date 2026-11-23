# KDE Craft blueprint for Saldo, used to build the Android APK.
# tools/build-apk.sh copies it into CraftMaster's blueprint folder and builds
# the local checkout (--options saldo.srcDir=<repo>), so the git URL below is
# only a default.
import info
from Blueprints.CraftPackageObject import CraftPackageObject
from CraftCore import CraftCore


class subinfo(info.infoclass):
    def setTargets(self):
        # Explicit target: setDefaultValues() needs the version.ini that only
        # exists inside craft-blueprints-kde.
        self.svnTargets["master"] = "https://github.com/hernique33comiitei/saldo.git"
        self.defaultTarget = "master"
        self.displayName = "Saldo"
        self.description = "Personal finances from Meu Pluggy"

    def setDependencies(self):
        self.buildDependencies["kde/frameworks/extra-cmake-modules"] = None
        self.runtimeDependencies["virtual/base"] = None
        self.runtimeDependencies["libs/qt/qtbase"] = None
        self.runtimeDependencies["libs/qt/qtdeclarative"] = None
        self.runtimeDependencies["libs/qt/qtsvg"] = None
        self.runtimeDependencies["kde/frameworks/tier1/kirigami"] = None
        self.runtimeDependencies["kde/frameworks/tier1/ki18n"] = None
        self.runtimeDependencies["kde/frameworks/tier1/kcoreaddons"] = None
        self.runtimeDependencies["kde/frameworks/tier1/kquickcharts"] = None
        self.runtimeDependencies["qt-libs/qtkeychain"] = None
        if CraftCore.compiler.platform.isAndroid:
            self.runtimeDependencies["kde/plasma/qqc2-breeze-style"] = None
        else:
            self.runtimeDependencies["kde/frameworks/tier1/breeze-icons"] = None
            self.runtimeDependencies["kde/frameworks/tier3/qqc2-desktop-style"] = None


class Package(CraftPackageObject.get("kde").pattern):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.subinfo.options.configure.args += ["-DBUILD_TESTING=OFF", "-DSALDO_USE_QTKEYCHAIN=ON"]
