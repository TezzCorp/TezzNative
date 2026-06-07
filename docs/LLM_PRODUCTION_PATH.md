# TezzNative LLM Production Path

This document answers the current LLM readiness question plainly:

> TezzNative cannot yet build, train, and serve a production-scale LLM from
> scratch.

It can now support the first reliable building blocks for tiny transformer
inference experiments and CPU fallback validation. That is an important step,
but it is not the same as a scalable LLM platform.

## What Works Now

The `llm_core` module provides dtype-explicit f64 transformer primitives:

- `matmul_f64`
- `rmsnorm_rows_f64`
- `softmax_rows_f64`
- `rope_f64`

The wrappers validate null pointers and shapes, call the runtime builtin path
when available, and fall back to scalar TezzNative implementations when a
backend reports unsupported behavior. The f64 name is intentional: TezzNative
`float` is ABI f64 today, so these APIs should not be confused with f32, f16,
bf16, or quantized production lanes.

The current gate checks:

- module import and type checking through `tests/conformance/stdlib`
- bytecode execution of the f64 kernel fixture
- native executable build/run on the current Windows/Linux x64 path
- runtime/VM memory tagging for f64 outputs written by builtin calls

## How To Build A Tiny Transformer Experiment Today

Use TezzNative for a small CPU-oriented inference prototype:

1. Keep tokenization and model conversion simple and deterministic.
2. Store weights in f64 arrays or slabs.
3. Use `llm_core.matmul_f64` for linear projections.
4. Use `llm_core.rmsnorm_rows_f64` before attention and feed-forward blocks.
5. Use `llm_core.rope_f64` for rotary position embedding.
6. Use `llm_core.softmax_rows_f64` for attention probabilities.
7. Validate with:

```bash
tezzc check tests/conformance/stdlib/llm_core_f64.tn
tezzc run tests/conformance/stdlib/llm_core_f64.tn --bc
tezzc buildexe tests/conformance/stdlib/llm_core_f64.tn ./llm_core_f64 --verify
```

This path is suitable for correctness experiments, education, and the first
runtime/backend tests. It is not suitable for training or serving large models.

## Main Gaps Before Production LLMs

Production LLM work needs more than a few math kernels. The missing foundation
is:

- dtype lanes for f32, f16, bf16, int8, uint8, and lower-bit quantized weights
- tensor ownership, shape, stride, view, and alignment contracts
- mmap-friendly model loading with a stable model format
- tokenizer correctness and compatibility tests
- KV-cache allocation and attention memory management
- GPU/NPU kernels with explicit backend availability and fallback reporting
- batching, streaming decode, sampling, and server runtime support
- distributed training/inference primitives
- autodiff, optimizers, checkpointing, and mixed precision if training from
  scratch is a goal
- benchmark gates for latency, throughput, memory, and numerical accuracy

## Promotion Plan

1. Add f32 kernels matching the f64 `llm_core` API.
2. Add f16/bf16 storage lanes with f32 accumulation.
3. Add int8/uint8 quantized matmul with calibration metadata.
4. Add a tensor descriptor type for shape, stride, dtype, and device.
5. Add model-load tests for a small frozen transformer checkpoint.
6. Add tokenizer fixtures with known prompt/token/output pairs.
7. Add CPU benchmark gates for each primitive.
8. Add GPU/NPU backend gates only when a real backend executes the kernels.
9. Add a tiny end-to-end decoder fixture before claiming LLM inference support.
10. Add training primitives only after inference correctness and memory rules
    are stable.

## Public Claim Boundary

The safe claim is:

> TezzNative has started a dtype-explicit LLM kernel foundation with f64 CPU
> primitives and fallback validation.

The unsafe claim is:

> TezzNative can build production LLMs from scratch today.

That broader claim should wait until the promotion plan has real source-visible
tests, benchmark data, and backend matrices.
