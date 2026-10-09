.PHONY: all build run stop clean

all: build

build:
	@chmod +x scripts/*.sh
	@./scripts/build.sh

run: build
	@./scripts/run.sh

stop:
	@chmod +x scripts/*.sh
	@./scripts/kill.sh

clean:
	@rm -rf build .build
	@echo "🧹 Cleaned build directory"
