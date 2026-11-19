# syntax=docker/dockerfile:1
# Static binary on distroless: no shell, no package manager, runs as UID 65532.

FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
ARG VERSION=dev
ARG COMMIT=unknown
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT}" \
      -o /out/app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app"]
