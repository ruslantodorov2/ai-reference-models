ARG TENSORFLOW_BASE_IMAGE="intel/intel-extension-for-tensorflow"
ARG TENSORFLOW_BASE_TAG="gpu-max"

FROM ${TENSORFLOW_BASE_IMAGE}:${TENSORFLOW_BASE_TAG}
