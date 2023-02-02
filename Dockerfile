ARG ALPINE_VERSION=3.16
ARG GO_VERSION=1.19
ARG GOLANGCI_LINT_VERSION=v1.49.0

FROM --platform=${BUILDPLATFORM} kbuley/binpot:golangci-lint-${GOLANGCI_LINT_VERSION} AS golangci-lint

FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS base
RUN apk --update add git g++
ENV CGO_ENABLED=0
COPY --from=golangci-lint /bin /go/bin/golangci-lint
WORKDIR /tmp/gobuild
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY internal/ ./internal/

FROM --platform=${BUILDPLATFORM} base AS lint
COPY .golangci.yml ./
RUN golangci-lint run --timeout=10m

FROM --platform=${BUILDPLATFORM} base AS build
ARG ALLTARGETPLATFORMS
RUN go build -o /usr/local/bin/xcputranslate cmd/xcputranslate/main.go
ARG TARGETPLATFORM
ARG VERSION=unknown
ARG BUILD_DATE="an unknown date"
ARG COMMIT=unknown
RUN xcputranslate sleep -buildtime=2s -targetplatform=${TARGETPLATFORM} -order=${ALLTARGETPLATFORMS} && \
  GOARCH="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -field arch)" \
  GOARM="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -field arm)" \
  go build -trimpath -ldflags="-s -w \
  -X 'main.version=$VERSION' \
  -X 'main.buildDate=$BUILD_DATE' \
  -X 'main.commit=$COMMIT' \
  " -o entrypoint cmd/xcputranslate/main.go

FROM scratch
ARG VERSION=unknown
ARG BUILD_DATE="an unknown date"
ARG COMMIT=unknown
LABEL \
  org.opencontainers.image.authors="kevin@buley.org" \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.version=$VERSION \
  org.opencontainers.image.revision=$COMMIT \
  org.opencontainers.image.url="https://github.com/kbuley/xcputranslate" \
  org.opencontainers.image.documentation="https://github.com/kbuley/xcputranslate" \
  org.opencontainers.image.source="https://github.com/kbuley/xcputranslate" \
  org.opencontainers.image.title="xcputranslate" \
  org.opencontainers.image.description=""
ENTRYPOINT ["/xcputranslate"]
USER 1000
COPY --from=build --chown=1000 /tmp/gobuild/entrypoint /xcputranslate
