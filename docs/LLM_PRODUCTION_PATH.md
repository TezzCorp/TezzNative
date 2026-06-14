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
- `matmul_i8_f64`
- `rmsnorm_rows_f64`
- `softmax_rows_f64`
- `rope_f64`

The wrappers validate null pointers and shapes, call the runtime builtin path
when available, and fall back to scalar TezzNative implementations when a
backend reports unsupported behavior. The f64 name is intentional: TezzNative
`float` is ABI f64 today, so these APIs should not be confused with f32, f16,
bf16, or lower-bit production lanes. `matmul_i8_f64` is the first quantized
weight lane: f64 activations multiplied by signed int8 weights with optional
per-output-column f64 dequant scales.

The current gate checks:

- module import and type checking through `tests/conformance/stdlib`
- bytecode execution of the f64 kernel fixture
- bytecode execution of the signed int8 quantized matmul fixture
- native executable build/run on the current Windows/Linux x64 path
- runtime/VM memory tagging for f64 outputs written by builtin calls

The TezzMind prototype now has a deterministic on-device AI verification path:

- `lib/mind.tn` builds and runs a tiny GQA transformer with RMSNorm, RoPE,
  SwiGLU, KV cache, save/load, deterministic generation, argmax, and checksum
  helpers.
- `lib/trainer.tn` provides AdamW training with gradient clipping, trainer
  telemetry getters, deterministic loss evaluation, and clearer final-loss
  behavior.
- `tests/conformance/native/tezzmind_verify_output.tn` builds and runs a
  source-visible native fixture for forward logits, generation, training loss
  decrease, checkpoint save/load, and checksum preservation.
- `projects/tezzmind/verify.tn` is the standalone project verifier for local
  output inspection.

## How To Build A Tiny Transformer Experiment Today

Use TezzNative for a small CPU-oriented inference prototype:

1. Keep tokenization and model conversion simple and deterministic.
2. Store weights in f64 arrays or signed int8 slabs with f64 scale vectors.
3. Use `llm_core.matmul_f64` or `llm_core.matmul_i8_f64` for linear projections.
4. Use `llm_core.rmsnorm_rows_f64` before attention and feed-forward blocks.
5. Use `llm_core.rope_f64` for rotary position embedding.
6. Use `llm_core.softmax_rows_f64` for attention probabilities.
7. Validate with:

```bash
tezzc check tests/conformance/stdlib/llm_core_f64.tn
tezzc run tests/conformance/stdlib/llm_core_f64.tn --bc
tezzc buildexe tests/conformance/stdlib/llm_core_f64.tn ./llm_core_f64 --verify
tezzc run tests/conformance/stdlib/llm_core_quant_i8.tn --bc
tezzc buildexe tests/conformance/stdlib/llm_core_quant_i8.tn ./llm_core_quant_i8 --verify
tezzc buildexe tests/conformance/native/tezzmind_verify_output.tn ./tezzmind_verify --verify
./tezzmind_verify
tezzc buildexe projects/tezzmind/verify.tn ./tezzmind_project_verify --verify
./tezzmind_project_verify
```

This path is suitable for correctness experiments, education, and the first
runtime/backend tests. It is not suitable for training or serving large models.

## Main Gaps Before Production LLMs

Production LLM work needs more than a few math kernels. The missing foundation
is:

- dtype lanes for f32, f16, bf16, uint8, and lower-bit quantized weights
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
- trained checkpoint quality gates before calling TezzMind a reasoning model

## Promotion Plan

1. Add f32 kernels matching the f64 `llm_core` API.
2. Add f16/bf16 storage lanes with f32 accumulation.
3. Extend the delivered int8 matmul lane with uint8, lower-bit packing, and
   calibration metadata.
4. Add a tensor descriptor type for shape, stride, dtype, and device.
5. Add model-load tests for a small frozen transformer checkpoint.
6. Add tokenizer fixtures with known prompt/token/output pairs.
7. Add CPU benchmark gates for each primitive.
8. Add GPU/NPU backend gates only when a real backend executes the kernels.
9. Add a tiny end-to-end decoder fixture before claiming LLM inference support.
10. Add training primitives only after inference correctness and memory rules
    are stable.
11. Expand TezzMind verification with trained checkpoint quality metrics,
    tokenizer fixtures, and reproducible output benchmarks before any
    reasoning-AI claim.

## Public Claim Boundary

The safe claim is:

> TezzNative has started a dtype-explicit LLM kernel foundation with f64 CPU
> primitives, signed int8-weight matmul, fallback validation, and a native
> TezzMind tiny-transformer verification path.

The unsafe claim is:

> TezzNative can build production LLMs from scratch today.

That broader claim should wait until the promotion plan has real source-visible
tests, benchmark data, and backend matrices.
