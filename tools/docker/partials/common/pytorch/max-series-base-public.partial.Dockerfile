ARG PYTORCH_BASE_IMAGE="intel/intel-extension-for-pytorch"
ARG PYTORCH_BASE_TAG="xpu-max"

FROM ${PYTORCH_BASE_IMAGE}:${PYTORCH_BASE_TAG}