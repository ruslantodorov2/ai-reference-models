#!/bin/bash

#
# Copyright (c) 2021 Intel Corporation
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
#


ARGS=""

export DNNL_PRIMITIVE_CACHE_CAPACITY=1024
#export MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000"

path="ipex"
ARGS="$ARGS --accuracy_only  --lambada"
echo "### running with intel extension for pytorch"

precision="fp32"
if [[ "$1" == "bf16" ]]
then
    precision="bf16"
    ARGS="$ARGS --dtype 'bf16' "
    echo "### running bf16 mode"
elif [[ "$1" == "fp32" ]]
then
    echo "### running fp32 mode"
elif [[ "$1" == "fp16" ]]
then
    precision=fp16
    ARGS="$ARGS --dtype 'fp16'"
    echo "### running fp16 mode"
elif [[ "$1" == "bf32" ]]
then
    precision="bf32"
    ARGS="$ARGS --dtype 'bf32'"
    echo "### running bf32 mode"
elif [[ "$1" == "int8-fp32" ]]
then
    precision="int8-fp32"
    ARGS="$ARGS --dtype fp32 --ipex-weight-only-quantization"
    echo "### running int8-fp32 mode"
elif [[ "$1" == "int8-bf16" ]]
then
    precision="int8-bf16"
    ARGS="$ARGS --int8-bf16-mixed --ipex-weight-only-quantization"
    echo "### running int8-bf16 mode"
else
    echo "The specified precision '$1' is unsupported."
    echo "Supported precisions are: fp32, bf32, bf16, fp16, int8-fp32, int8-bf16"
    exit 1
fi


if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set, please create the output path and set it to OUTPUT_DIR"
  exit 1
fi

mode="jit"
ARGS="$ARGS --jit"
echo "### running with jit mode"


FINETUNED_MODEL=${FINETUNED_MODEL:-"'bigscience/bloom'"}

EVAL_SCRIPT=${EVAL_SCRIPT:-"../../../../../../models/language_modeling/pytorch/bloom/inference/cpu/run_llm.py"}
WORK_SPACE=${WORK_SPACE:-${OUTPUT_DIR}}
rm -rf ${OUTPUT_DIR}/accuracy_log*
deepspeed --bind_cores_to_rank \
  ${EVAL_SCRIPT} $ARGS \
  --model-name-or-path   ${FINETUNED_MODEL} 2>&1 | tee ${OUTPUT_DIR}/accuracy_log_${precision}_${mode}.log
