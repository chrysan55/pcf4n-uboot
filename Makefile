SHELL := /bin/bash

include config/versions.env

IMAGE ?= bootstrap-builder:26.1
WORK_DIR ?= $(CURDIR)/.work
OUTPUT_DIR ?= $(CURDIR)/output

.PHONY: help image lock fetch build build-atf build-uboot build-linux \
	build-rootfs package check release-check clean remote-build

help:
	@printf '%s\n' \
	  'make image         Build the pinned host tool container' \
	  'make lock          Resolve release refs to immutable commits' \
	  'make fetch         Fetch all source repositories at locked commits' \
	  'make build         Build ATF, U-Boot, Linux, rootfs, and packages' \
	  'make package       Assemble TFTP and logic-team handoff artifacts' \
	  'make check         Run static and configuration checks' \
	  'make release-check Enforce production release gates' \
	  'make remote-build  Sync and build on the configured remote host' \
	  'make clean         Remove generated .work and output directories'

image:
	docker build --pull \
	  --build-arg "BASE_IMAGE=$(BASE_IMAGE)@$(BASE_IMAGE_DIGEST)" \
	  --tag "$(IMAGE)" .

lock:
	./scripts/update-lock.sh

fetch:
	./scripts/container.sh ./scripts/fetch-sources.sh

build: build-atf build-uboot build-linux build-rootfs package

build-atf:
	./scripts/container.sh ./scripts/build-atf.sh

build-uboot: build-atf
	./scripts/container.sh ./scripts/build-uboot.sh

build-linux:
	./scripts/container.sh ./scripts/build-linux.sh

build-rootfs: build-linux
	./scripts/container.sh ./scripts/build-rootfs.sh

package:
	./scripts/container.sh ./scripts/package.sh

check:
	./scripts/check.sh

release-check:
	./scripts/release-check.sh

remote-build:
	./scripts/remote-build.sh

clean:
	./scripts/clean.sh
