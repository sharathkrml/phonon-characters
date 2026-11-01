APP_NAME := Phonon Characters
RELEASE_APP := build-release/Build/Products/Release/$(APP_NAME).app
DEBUG_APP := build/Build/Products/Debug/$(APP_NAME).app
LOGS := $(HOME)/Library/Application Support/PhononCharacters/Logs

.DEFAULT_GOAL := help

.PHONY: help project build dmg run debug clean notarize logs models

help: ## Show this list
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-9s %s\n", $$1, $$2}'

project: ## Regenerate PhononCharacters.xcodeproj from project.yml
	xcodegen generate

build: ## Release build, signed (ad-hoc unless CODESIGN_IDENTITY is set)
	./Packaging/build.sh

dmg: build ## Build release app and wrap it in dist/PhononCharacters-*.dmg
	./Packaging/make-dmg.sh

run: build ## Build release and launch it
	open "$(RELEASE_APP)"

debug: ## Debug build and launch (faster edit loop)
	xcodegen generate
	xcodebuild -project PhononCharacters.xcodeproj -scheme PhononCharacters \
		-configuration Debug -derivedDataPath build ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
	open "$(DEBUG_APP)"

logs: ## Follow the app log
	tail -f "$(LOGS)/app.log"

models: ## Show what is installed and how much space it uses
	@du -sh "$(HOME)/Library/Application Support/PhononTTS/models" \
		"$(HOME)/Library/Application Support/PhononCharacters/Models" \
		"$(HOME)/Library/Application Support/PhononCharacters/Ears" \
		"$(HOME)/.cache/fermion/speech" 2>/dev/null || true
	@df -h "$(HOME)" | tail -1

notarize: ## Notarize the built DMG (needs a Developer ID + NOTARY_PROFILE)
	./Packaging/notarize.sh

clean: ## Remove build outputs and the DMG
	rm -rf build build-release dist
