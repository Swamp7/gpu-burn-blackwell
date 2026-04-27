# syntax=docker/dockerfile:1
#
# gpu-burn built against CUDA 13 for modern NVIDIA GPUs.
#
# Default COMPUTE=75 (Turing baseline) generates compute_75 PTX, which the
# CUDA driver JIT-compiles to any target sm_75 or higher at runtime. The
# bulk of work is done in cuBLAS (which contains arch-tuned kernels for
# every supported architecture in its own fatbin), so the small comparison
# kernel being JIT'd adds negligible overhead. Net effect: one image runs
# correctly on Turing / Ampere / Ada / Hopper / Blackwell. CUDA 13 does
# not support compute_70 (Volta) — V100 users need an older CUDA base.
#
# Override at build time if you want native SASS for a specific architecture:
#   docker build --build-arg COMPUTE=120 -t gpu-burn:blackwell . # 5090 / RTX PRO 6000 WS
#   docker build --build-arg COMPUTE=100 -t gpu-burn:b100      . # B100 / B200
#   docker build --build-arg COMPUTE=90  -t gpu-burn:hopper    . # H100 / H200
#   docker build --build-arg COMPUTE=89  -t gpu-burn:ada       . # 4090 / L40
#   docker build --build-arg COMPUTE=86  -t gpu-burn:ampere    . # 3090 / A40
#
# Run (Docker 19.03+ with NVIDIA Container Toolkit):
#   docker run --rm --gpus all gpu-burn:latest 120
# Or with the legacy nvidia runtime:
#   docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all gpu-burn:latest 120

ARG CUDA_TAG=13.0.0-devel-ubuntu22.04
ARG CUDA_RUNTIME_TAG=13.0.0-runtime-ubuntu22.04

FROM nvidia/cuda:${CUDA_TAG} AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends git make ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG GPU_BURN_REF=master
RUN git clone --depth=1 --branch "${GPU_BURN_REF}" https://github.com/wilicc/gpu-burn /opt/gpu-burn

WORKDIR /opt/gpu-burn

ARG COMPUTE=75
RUN make COMPUTE=${COMPUTE}


FROM nvidia/cuda:${CUDA_RUNTIME_TAG}

COPY --from=builder /opt/gpu-burn/gpu_burn   /usr/local/bin/gpu_burn
COPY --from=builder /opt/gpu-burn/compare.ptx /usr/local/bin/compare.ptx

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

WORKDIR /usr/local/bin
ENTRYPOINT ["gpu_burn"]
CMD ["120"]
