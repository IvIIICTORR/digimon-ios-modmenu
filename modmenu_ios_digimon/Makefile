# Digimon iOS Mod Menu - baseado no template Komaru (Titanox, sem jailbreak)
# https://theos.dev
#
# Mudancas em relacao ao Makefile do template:
#   - TWEAK_NAME = DigimonMenu  (o filter plist TEM de se chamar DigimonMenu.plist)
#   - Metal e MetalKit adicionados aos frameworks (o backend do ImGui usa os dois;
#     o template compila sem eles em alguns setups, mas linkar explicitamente
#     evita erro de simbolo no runner)
# O resto e identico, inclusive a lista de arquivos do Titanox - nao mexer nela.

ARCHS = arm64
TARGET = iphone:clang:latest:latest

DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DigimonMenu

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController Metal MetalKit

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wall -Wno-error -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function
$(TWEAK_NAME)_CCFLAGS = -std=c++17 -fno-rtti -DNDEBUG -Wall -Wno-error -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-writable-strings -Wno-nontrivial-memcall

$(TWEAK_NAME)_FILES = MenuLoad/ImGuiDrawView.xm \
                      $(wildcard MenuLoad/*.mm) \
                      $(wildcard Source/*.mm) \
                      $(wildcard ImGui/*.mm) \
                      $(wildcard ImGui/*.cpp) \
                      $(wildcard utils/Komaru/*.mm) \
                      $(wildcard utils/Komaru/*.cpp) \
                      utils/libtitanox/brk_hook/Hook/hook.c \
                      utils/libtitanox/brk_hook/Hook/mach_excServer.c \
                      $(wildcard utils/libtitanox/**/*.mm) \
                      $(wildcard utils/libtitanox/**/*.cpp) \
                      $(filter-out utils/libtitanox/brk_hook/Hook/hook.c, $(wildcard utils/libtitanox/**/*.c))

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS)/makefiles/aggregate.mk
