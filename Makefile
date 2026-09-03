APP_NAME = MonoTab
BUNDLE_NAME = $(APP_NAME).app
BUILD_DIR = .build/release
APP_DIR = $(BUNDLE_NAME)/Contents
XCODE_DEV_DIR ?= /Applications/Xcode.app/Contents/Developer
LOCAL_BIN_DIR ?= $(HOME)/.local/bin

.PHONY: all build test app run run-cli install install-local clean

all: app

build:
	DEVELOPER_DIR=$(XCODE_DEV_DIR) swift build -c release --arch arm64

test:
	DEVELOPER_DIR=$(XCODE_DEV_DIR) swift test --arch arm64

CODESIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $$2}')
ifeq ($(strip $(CODESIGN_IDENTITY)),)
	CODESIGN_IDENTITY = -
endif

app: build
	@echo "==> Criando bundle $(BUNDLE_NAME)..."
	@mkdir -p $(APP_DIR)/MacOS
	@mkdir -p $(APP_DIR)/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_DIR)/MacOS/
	@cp Resources/Info.plist $(APP_DIR)/Info.plist
	@cp Resources/AppIcon.icns $(APP_DIR)/Resources/AppIcon.icns
	@echo "==> Assinando bundle com $(CODESIGN_IDENTITY) e Entitlements..."
	@codesign --force --deep --sign "$(CODESIGN_IDENTITY)" --entitlements Resources/Entitlements.plist $(BUNDLE_NAME)
	@echo "==> $(BUNDLE_NAME) criado com sucesso!"

run: app
	@echo "==> Iniciando $(BUNDLE_NAME)..."
	open $(BUNDLE_NAME)

run-cli: build
	@echo "==> Executando binário diretamente..."
	$(BUILD_DIR)/$(APP_NAME)

install: app
	@echo "==> Encerrando instâncias antigas em execução..."
	@killall $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@echo "==> Limpando instalações duplicadas ou antigas..."
	@rm -rf /Applications/monotab.app /Applications/MonoTab.app
	@echo "==> Instalando $(BUNDLE_NAME) em /Applications..."
	@cp -R $(BUNDLE_NAME) /Applications/
	@touch /Applications/$(BUNDLE_NAME)
	@echo "==> Criando atalhos CLI em $(LOCAL_BIN_DIR)..."
	@mkdir -p $(LOCAL_BIN_DIR)
	@ln -sf /Applications/$(BUNDLE_NAME)/Contents/MacOS/$(APP_NAME) $(LOCAL_BIN_DIR)/MonoTab
	@ln -sf /Applications/$(BUNDLE_NAME)/Contents/MacOS/$(APP_NAME) $(LOCAL_BIN_DIR)/monotab
	@echo "==> Reiniciando $(APP_NAME) atualizado..."
	@open /Applications/$(BUNDLE_NAME)
	@echo "==> $(APP_NAME) instalado e iniciado com sucesso!"

install-local: install

clean:
	@rm -rf .build $(BUNDLE_NAME)
	@echo "==> Limpeza concluída."
