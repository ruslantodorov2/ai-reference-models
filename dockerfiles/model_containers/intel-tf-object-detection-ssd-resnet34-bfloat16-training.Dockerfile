# Copyright (c) 2020-2021 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
#
# THIS IS A GENERATED DOCKERFILE.
#
# This file was assembled from multiple pieces, whose use is documented
# throughout. Please refer to the TensorFlow dockerfiles documentation
# for more information.

ARG TENSORFLOW_IMAGE="intel/intel-optimized-tensorflow"

ARG TENSORFLOW_TAG="latest"

FROM ${TENSORFLOW_IMAGE}:${TENSORFLOW_TAG}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends --fix-missing -y \
        libsm6 \
        libxext6 \
        python-tk && \
    pip install requests

ARG PY_VERSION="3.9"

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
        build-essential \
        python${PY_VERSION}-dev

ARG TF_MODELS_BRANCH="8110bb64ca63c48d0caee9d565e5b4274db2220a"

ARG FETCH_PR

ARG CODE_DIR=/tensorflow/models

ENV TF_MODELS_DIR=${CODE_DIR}

RUN apt-get update && \
    apt-get install --no-install-recommends --fix-missing -y git && \
    git clone https://github.com/tensorflow/models.git ${CODE_DIR} && \
    ( cd ${CODE_DIR} && \
    if [ ! -z "${FETCH_PR}" ]; then git fetch origin ${FETCH_PR}; fi && \
    git checkout ${TF_MODELS_BRANCH} )

# Note pycocotools has to be install after the other requirements
RUN pip install \
        Cython \
        contextlib2 \
        jupyter \
        lxml \
        matplotlib \
        numpy>=1.17.4 \
        'pillow>=8.1.2' && \
    pip install pycocotools

ARG TF_MODELS_DIR=/tensorflow/models

# Downloads protoc and runs it for object detection
RUN cd ${TF_MODELS_DIR}/research && \
    apt-get install --no-install-recommends --fix-missing -y \
        unzip \
        wget && \
    wget --quiet -O protobuf.zip https://github.com/google/protobuf/releases/download/v3.3.0/protoc-3.3.0-linux-x86_64.zip && \
    unzip -o protobuf.zip && \
    rm protobuf.zip && \
    ./bin/protoc object_detection/protos/*.proto --python_out=. && \
    apt-get remove -y \
        unzip \
        wget && \
    apt-get autoremove -y

ARG PY_VERSION="3.9"

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
        build-essential \
        python${PY_VERSION}-dev

RUN apt-get update && \
    apt-get install --no-install-recommends --fix-missing -y \
    python3-apt \
    software-properties-common

RUN apt-get update && \
    apt-get install --no-install-recommends --fix-missing -y \
        gcc-8 \
        g++-8 && \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 8 && \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 8

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing curl

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.3/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv kubectl /usr/local/bin

RUN apt-get install --no-install-recommends --fix-missing -y \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    openssh-client \
    openssh-server

RUN apt-get install --no-install-recommends --fix-missing -y \
    openssh-client \
    openssh-server \
    systemd && \
    systemctl enable ssh

ARG HOROVOD_VERSION="11c1389"

ENV HOROVOD_WITHOUT_MXNET=1 \
    HOROVOD_WITHOUT_PYTORCH=1 \
    HOROVOD_WITH_TENSORFLOW=1

# In case installing released versions of Horovod fail,and there is
# a working commit replace next set of RUN commands with something like:
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    cmake \
    git
RUN pip install git+https://github.com/horovod/horovod.git@${HOROVOD_VERSION}

# RUN apt-get update && \
#     apt-get install -y --no-install-recommends --fix-missing \
#     cmake
#
# RUN pip install git+https://github.com/horovod/horovod.git@${HOROVOD_VERSION}

RUN apt-get update && \
    apt-get install -y cpio

RUN pip install tensorflow-addons==0.17.1

RUN pip install opencv-python

ARG PACKAGE_DIR=model_packages

ARG PACKAGE_NAME="ssd-resnet34-bfloat16-training"

ARG MODEL_WORKSPACE

# ${MODEL_WORKSPACE} and below needs to be owned by root:root rather than the current UID:GID
# this allows the default user (root) to work in k8s single-node, multi-node
RUN umask 002 && mkdir -p ${MODEL_WORKSPACE} && chgrp root ${MODEL_WORKSPACE} && chmod g+s+w,o+s+r ${MODEL_WORKSPACE}

ADD --chown=0:0 ${PACKAGE_DIR}/${PACKAGE_NAME}.tar.gz ${MODEL_WORKSPACE}

RUN chown -R root ${MODEL_WORKSPACE}/${PACKAGE_NAME} && chgrp -R root ${MODEL_WORKSPACE}/${PACKAGE_NAME} && chmod -R g+s+w ${MODEL_WORKSPACE}/${PACKAGE_NAME} && find ${MODEL_WORKSPACE}/${PACKAGE_NAME} -type d | xargs chmod o+r+x 

WORKDIR ${MODEL_WORKSPACE}/${PACKAGE_NAME}

ENV USER_ID=0

ENV USER_NAME=root

ENV GROUP_ID=0

ENV GROUP_NAME=root

RUN apt-get update && \
    apt-get install --no-install-recommends --fix-missing -y gosu

RUN echo '#!/bin/bash\n\
USER_ID=$USER_ID\n\
USER_NAME=$USER_NAME\n\
GROUP_ID=$GROUP_ID\n\
GROUP_NAME=$GROUP_NAME\n\
if [[ $GROUP_NAME != root ]]; then\n\
  groupadd -r -g $GROUP_ID $GROUP_NAME\n\
fi\n\
if [[ $USER_NAME != root ]]; then\n\
  useradd --no-log-init -r -u $USER_ID -g $GROUP_NAME -s /bin/bash -M $USER_NAME\n\
fi\n\
exec /usr/sbin/gosu $USER_NAME:$GROUP_NAME "$@"\n '\
>> /tmp/entrypoint.sh

RUN chmod u+x,g+x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]

RUN cd ${TF_MODELS_DIR} && \
    git apply --ignore-space-change --ignore-whitespace ${MODEL_WORKSPACE}/${PACKAGE_NAME}/models/object_detection/tensorflow/ssd-resnet34/training/bfloat16/tf-2.0.diff
