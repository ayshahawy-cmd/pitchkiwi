.PHONY: bootstrap build test app smoke clean

bootstrap:
	./scripts/bootstrap.sh

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

smoke:
	@test -n "$(AUDIO)" || (echo "Usage: make smoke AUDIO=/absolute/path/to/audio" && exit 2)
	swift run horme-flow-smoke .models/ggml-base.en.bin "$(AUDIO)"

clean:
	swift package clean
