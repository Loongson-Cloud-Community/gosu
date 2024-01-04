FROM golang:1.21-buster

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		file \
		patch \
	; \
	rm -rf /var/lib/apt/lists/*

# note: we cannot add "-s" here because then "govulncheck" does not work (see SECURITY.md); the ~0.2MiB increase (as of 2022-12-16, Go 1.18) is worth it
ENV BUILD_FLAGS="-v -ldflags '-d -w'"

RUN set -eux; \
	{ \
		echo '#!/usr/bin/env bash'; \
		echo 'set -Eeuo pipefail -x'; \
		echo 'eval "go build $BUILD_FLAGS -o /go/bin/gosu-$ARCH"'; \
		echo 'file "/go/bin/gosu-$ARCH"'; \
	} > /usr/local/bin/gosu-build-and-test.sh; \
	chmod +x /usr/local/bin/gosu-build-and-test.sh

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

WORKDIR /go/src/github.com/tianon/gosu

COPY go.mod go.sum ./
RUN set -eux; \
	go mod download; \
	go mod verify

COPY *.go ./

# gosu-$(dpkg --print-architecture)
RUN ARCH=amd64       GOARCH=amd64       gosu-build-and-test.sh
RUN ARCH=arm64       GOARCH=arm64       gosu-build-and-test.sh
RUN ARCH=loongarch64 GOARCH=loong64     gosu-build-and-test.sh

RUN set -eux; ls -lAFh /go/bin/gosu-*; file /go/bin/gosu-*
