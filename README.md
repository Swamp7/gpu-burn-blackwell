# gpu-burn-blackwell

A small Docker image that builds [wilicc/gpu-burn](https://github.com/wilicc/gpu-burn) against CUDA 13. The default build runs on **any GPU from Turing onward** (T4, RTX 20xx, Ampere, Ada, Hopper, Blackwell) because the comparison kernel is compiled to `compute_75` PTX and the driver JITs it to whatever silicon you point it at. The heavy lifting happens inside cuBLAS, which contains arch-tuned kernels for every supported architecture, so a 5090 still gets Blackwell-tuned cuBLAS kernels through the same image. CUDA 13 dropped support for Volta (V100, sm_70) — V100 users need to base on an older CUDA image.

The popular pre-built `gpu-burn` images on Docker Hub are CUDA 8 / CUDA 11.1 vintage. They run on a 5090 via PTX JIT, but their bundled cuBLAS has no Blackwell-tuned kernels, so the FLOP/s number you see is well below what the card can actually deliver. A fresh build against CUDA 13 fixes that.

## Quick start (prebuilt image)

The prebuilt image runs on Turing and newer (T4 / RTX 20xx / A100 / 30xx / 40xx / H100 / B100 / 5090 / RTX PRO 6000 WS) without rebuilding:

```bash
docker pull swamp7/gpu-burn:cuda13
docker run --rm --gpus all swamp7/gpu-burn:cuda13 120
# Or with the legacy nvidia runtime:
docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all swamp7/gpu-burn:cuda13 120
```

If you want native SASS for a specific architecture instead of JIT'ing from compute_75 PTX, build locally with the appropriate `COMPUTE` value (see below).

## Build

```bash
# Default: compute_75 PTX, runs on Turing+ via JIT
docker build -t gpu-burn:cuda13 .

# Native sm_120 (5090 / RTX PRO 6000 Blackwell Workstation)
docker build --build-arg COMPUTE=120 -t gpu-burn:blackwell .

# Native sm_100 (B100 / B200)
docker build --build-arg COMPUTE=100 -t gpu-burn:b100 .

# Native sm_90 (H100 / H200)
docker build --build-arg COMPUTE=90  -t gpu-burn:hopper .

# Native sm_89 (4090 / L40)
docker build --build-arg COMPUTE=89  -t gpu-burn:ada .

# Native sm_86 (3090 / A40)
docker build --build-arg COMPUTE=86  -t gpu-burn:ampere .

# Pin gpu-burn to a specific upstream ref instead of master
docker build --build-arg GPU_BURN_REF=v1.1 -t gpu-burn:cuda13 .
```

## Run

```bash
# Burn all visible GPUs for 120 seconds
docker run --rm --gpus all gpu-burn:cuda13 120

# Older nvidia runtime
docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all gpu-burn:cuda13 120
```

`gpu-burn` runs an FP32 cuBLAS matrix-multiply loop, prints sustained TFLOP/s and temperature per GPU, and reports OK / errors at the end.

## What this is and isn't

It is a synthetic FP32 burn — useful for catching arithmetic errors under sustained load and for thermal/power qualification. It is **not** a comprehensive GPU diagnostic. For broader validation (memory bandwidth, NVLink, ECC, PCIe, FP16/FP64/Tensor Core, driver-level health), use `dcgmi diag` from NVIDIA's Data Center GPU Manager.

A reasonable rental-prep flow is `dcgmi diag -r 3` for breadth, then this image for sustained thermal/FP32 stability.

## Compute capabilities cheatsheet

| Arch | sm_ | Examples |
|---|---|---|
| Pascal | 60, 61 | P100, GTX 10xx |
| Volta | 70 | V100 |
| Turing | 75 | T4, RTX 20xx |
| Ampere | 80, 86 | A100, RTX 30xx |
| Ada Lovelace | 89 | RTX 4090, L40 |
| Hopper | 90 | H100, H200 |
| Blackwell (DC) | 100 | B100, B200 |
| Blackwell (Workstation/Consumer) | 120 | RTX 5090, RTX PRO 6000 Blackwell Workstation |

## Credits

Built on top of [wilicc/gpu-burn](https://github.com/wilicc/gpu-burn) by Ville Timonen. This repository is a thin Docker wrapper; all of the actual work happens upstream.

## License

MIT for the wrapper in this repository (see `LICENSE`). The upstream `gpu-burn` source pulled at build time is BSD-2-Clause; refer to its repository for its own licensing.
