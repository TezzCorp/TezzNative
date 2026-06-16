# TezzNative LLM Production Path

This document answers the current LLM readiness question plainly:

> TezzNative cannot yet build, train, and serve a production-scale LLM from
> scratch.

It can now support source-visible building blocks for tiny transformer
inference experiments, dtype/storage validation, checkpoint compatibility
checks, and CPU fallback validation. That is an important step, but it is not
the same as a scalable LLM platform.

## What Works Now

The `llm_core` module provides dtype-explicit CPU transformer primitives:

- `matmul_f64`
- `matmul_f32`
- `matmul_i8_f64`
- `matmul_u8_f64`
- `matmul_q4_f64`
- `matmul_f16_f32`
- `matmul_bf16_f32`
- `rmsnorm_rows_f64`
- `rmsnorm_rows_f32`
- `softmax_rows_f64`
- `softmax_rows_f32`
- `rope_f64`
- `rope_f32`

The wrappers validate null pointers and shapes, call the runtime builtin path
when available, and fall back to scalar TezzNative implementations when a
backend reports unsupported behavior. The f64 name is intentional: TezzNative
`float` is ABI f64 today. The f32 APIs currently provide the same API shape and
CPU fallback contract; true packed f32 storage and accelerated f32 backend
kernels remain a later backend task. The f16 and bf16 lanes use 16-bit storage
values with f32-style accumulation into TezzNative `float` outputs. Quantized
lanes now cover signed int8, uint8, and packed q4 CPU fallback paths with
calibration metadata helpers.

The `tensor` module now has descriptor metadata for dtype, shape, stride,
device, alignment, element bytes, logical size, and byte size. Native-facing
code should prefer the pointer-fill descriptor APIs so large descriptors do not
depend on by-value struct ABI behavior.

The tokenizer baseline now includes stateless byte-token known-answer helpers
for allocator-independent fixtures. The full BPE tokenizer remains beta and
needs larger compatibility fixtures before tokenizer compatibility claims are
made.

The current gate checks:

- module import and type checking through `tests/conformance/stdlib`
- bytecode execution of the f64 kernel fixture
- bytecode execution of the signed int8 quantized matmul fixture
- native executable build/run for f32, f16, bf16, uint8, q4, tensor
  descriptors, tokenizer known answers, KV-cache rules, and tiny decoder argmax
  on Windows/Linux x64; TezzMind frozen/trained checkpoint native execution is
  currently Windows-gated while Linux `mind` native lowering is fixed
- runtime/VM memory tagging for f64 outputs written by builtin calls
- fail-closed GPU/NPU backend availability gates until a real backend executes
  the requested kernel
- a source-visible `benchmarks/tezz/llm_core_matmul.tn` workload for CPU
  latency, throughput, memory, and output-hash measurement through the public
  benchmark harness

The TezzMind prototype now has a deterministic on-device AI verification path:

- `lib/mind.tn` builds and runs a tiny GQA transformer with RMSNorm, RoPE,
  SwiGLU, KV cache, save/load, deterministic generation, argmax, and checksum
  helpers.
- `lib/trainer.tn` provides AdamW training with gradient clipping, trainer
  telemetry getters, deterministic loss evaluation, and clearer final-loss
  behavior.
- `tests/conformance/native/tezzmind_verify_output.tn` builds and runs a
  source-visible Windows-native fixture for forward logits, generation,
  training loss decrease, checkpoint save/load, and checksum preservation.
- `tests/conformance/native/tezzmind_frozen_checkpoint.tn` validates a tiny
  frozen checkpoint shape/checksum/load path on the Windows native lane.
- `tests/conformance/native/tezzmind_trained_checkpoint_eval.tn` validates
  training loss decrease, checkpoint save/load, and post-load evaluation loss
  on the Windows native lane before any stronger behavior claim.
- `projects/tezzmind/verify.tn` is the standalone project verifier for local
  output inspection.

## How To Build A Tiny Transformer Experiment Today

Use TezzNative for a small CPU-oriented inference prototype:

1. Keep tokenization and model conversion simple and deterministic.
2. Store weights in f64 arrays, 16-bit f16/bf16 storage lanes, signed int8,
   uint8, or q4 slabs with explicit scales/zero points.
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
tezzc buildexe tests/conformance/native/llm_core_dtype_lanes.tn ./llm_core_dtype_lanes --verify
tezzc buildexe tests/conformance/native/tensor_descriptor.tn ./tensor_descriptor --verify
tezzc buildexe tests/conformance/native/tokenizer_known_answers.tn ./tokenizer_known_answers --verify
tezzc buildexe tests/conformance/native/llm_decode_memory_rules.tn ./llm_decode_memory_rules --verify
tezzc buildexe tests/conformance/native/tezzmind_verify_output.tn ./tezzmind_verify --verify
tezzc buildexe tests/conformance/native/tezzmind_frozen_checkpoint.tn ./tezzmind_frozen_checkpoint --verify
tezzc buildexe tests/conformance/native/tezzmind_trained_checkpoint_eval.tn ./tezzmind_trained_checkpoint_eval --verify
./tezzmind_verify
tezzc buildexe projects/tezzmind/verify.tn ./tezzmind_project_verify --verify
./tezzmind_project_verify
```

This path is suitable for correctness experiments, education, and the first
runtime/backend tests. It is not suitable for training or serving large models.

## Main Gaps Before Production LLMs

Production LLM work needs more than a few math kernels. The missing foundation
is:

- accelerated packed f32/f16/bf16 kernels with backend-specific layouts
- tensor ownership, view slicing, and allocator contracts beyond descriptors
- mmap-friendly model loading with a stable model format and real mmap path
- tokenizer compatibility tests against real vocab/merge fixtures
- KV-cache allocation and attention memory management
- GPU/NPU kernels with explicit backend availability and fallback reporting
- batching, streaming decode, sampling, and server runtime support
- distributed training/inference primitives
- autodiff, optimizers, checkpointing, and mixed precision if training from
  scratch is a goal
- published benchmark runs for latency, throughput, memory, and numerical
  accuracy on named hardware
- trained checkpoint quality gates with held-out evaluation before calling
  TezzMind a reasoning model

## Promotion Plan

1. Add true packed f32 storage/backends and accelerated f16/bf16 kernels.
2. Add a stable mmap-capable model container with descriptor-checked tensors.
3. Add tokenizer compatibility fixtures for real vocab/merge files.
4. Add an end-to-end decoder fixture that combines tokenizer, checkpoint,
   KV-cache, logits, and decode output in one test.
5. Add CPU benchmark result baselines and numerical tolerances for each
   primitive.
6. Add GPU/NPU backend gates only when a real backend executes the kernels.
7. Add training primitives only after inference correctness and memory rules
   are stable.
8. Expand TezzMind verification with held-out trained checkpoint quality
   metrics, tokenizer fixtures, and reproducible output benchmarks before any
   reasoning-AI claim.

## Public Claim Boundary

The safe claim is:

> TezzNative has a dtype-explicit CPU LLM kernel foundation with f64/f32 API
> lanes, f16/bf16 storage lanes, int8/uint8/q4 quantized matmul, tensor and
> KV-cache descriptors, tokenizer byte fixtures, fail-closed GPU/NPU gates,
> benchmark fixtures, and Windows-native TezzMind tiny-transformer checkpoint
> verification.

The unsafe claim is:

> TezzNative can build production LLMs from scratch today.

That broader claim should wait until the promotion plan has real source-visible
tests, benchmark data, and backend matrices.
