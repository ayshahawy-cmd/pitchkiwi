.PHONY: bootstrap build test app release smoke clean

bootstrap:
	./scripts/bootstrap.sh

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

release:
	./scripts/package-release.sh

smoke:
	@test -n "$(AUDIO)" || (echo "Usage: make smoke AUDIO=/absolute/path/to/audio" && exit 2)
	swift run pitchkiwi-smoke .models/ggml-base.en.bin "$(AUDIO)"

clean:
	swift package clean
