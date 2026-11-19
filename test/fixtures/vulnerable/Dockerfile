# Deliberately outdated base image with known CRITICAL CVEs. Used only by
# the e2e test to prove that a correctly signed and attested image is still
# refused when its own scan says it is vulnerable.
FROM alpine:3.10.0
USER 65532:65532
ENTRYPOINT ["sleep", "3600"]
