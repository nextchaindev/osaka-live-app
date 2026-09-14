# default variables (can be overridden when calling make)
FLAVOR ?= dev
ENVIRONMENT ?= dev
RUN_MODE ?= release

# Run application (release mode by default so iOS can launch without a debugger)
run:
	flutter run --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT) --$(RUN_MODE)

run-debug:
	$(MAKE) run RUN_MODE=debug

run-dev:
	make run FLAVOR=dev ENVIRONMENT=dev

run-staging:
	make run FLAVOR=staging ENVIRONMENT=staging

run-prod:
	make run FLAVOR=prod ENVIRONMENT=prod

# Build application
build:
	flutter build --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT)

build-dev:
	make build FLAVOR=dev ENVIRONMENT=dev

build-staging:
	make build FLAVOR=staging ENVIRONMENT=staging

build-prod:
	make build FLAVOR=prod ENVIRONMENT=prod

# Build iOS application (xcode project)
build-ios:
	flutter build ios --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT)

build-ios-dev:
	make build-ios FLAVOR=dev ENVIRONMENT=dev

build-ios-staging:
	make build-ios FLAVOR=staging ENVIRONMENT=staging

build-ios-prod:
	make build-ios FLAVOR=prod ENVIRONMENT=prod

# Build iOS IPA (upload to AppStore/TestFlight)
build-ipa:
	flutter build ipa --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT) --export-options-plist=ios/exportOptions-$(FLAVOR).plist

build-ipa-dev:
	make build-ipa FLAVOR=dev ENVIRONMENT=dev

build-ipa-staging:
	make build-ipa FLAVOR=staging ENVIRONMENT=staging

build-ipa-prod:
	make build-ipa FLAVOR=prod ENVIRONMENT=prod

# Build Android application (APK)
build-android:
	flutter build apk --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT)

build-android-dev:
	make build-android FLAVOR=dev ENVIRONMENT=dev

build-android-staging:
	make build-android FLAVOR=staging ENVIRONMENT=staging

build-android-prod:
	make build-android FLAVOR=prod ENVIRONMENT=prod

# Build Android application (AAB)
build-appbundle:
	flutter build appbundle --flavor $(FLAVOR) --dart-define=ENVIRONMENT=$(ENVIRONMENT)

build-appbundle-dev:
	make build-appbundle FLAVOR=dev ENVIRONMENT=dev

build-appbundle-staging:
	make build-appbundle FLAVOR=staging ENVIRONMENT=staging

build-appbundle-prod:
	make build-appbundle FLAVOR=prod ENVIRONMENT=prod


# Additional commands
analyze:
	flutter analyze

format:
	dart format .

test:
	flutter test

clean:
	flutter clean
	rm -rf ios/Pods ios/Podfile.lock pubspec.lock

# Run application in release mode
run-release:
	$(MAKE) run FLAVOR=prod ENVIRONMENT=prod RUN_MODE=release

build-runner:
	dart run build_runner build --delete-conflicting-outputs


clean-ios:
	flutter clean
	flutter pub get
	cd ios && pod install
	cd ../
