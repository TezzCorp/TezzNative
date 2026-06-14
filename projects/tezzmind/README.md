# TezzMind - On-Device AI Prototype

**Built entirely in TezzNative language. Runs on any device. No cloud required.**

---

## What is TezzMind?

TezzMind is a compact transformer prototype written 100% in TezzNative.
It demonstrates that you can build and run an on-device AI model using only the TezzNative language
stack — no Python, no PyTorch, no ONNX dependencies.

TezzMind uses a **modern transformer architecture**:

| Component | Choice | Why |
|-----------|--------|-----|
| Attention | **Grouped Query Attention (GQA)** | Fewer KV heads → lower memory usage |
| FFN | **SwiGLU** | State-of-the-art gated activation (LLaMA2/Mistral) |
| Positional encoding | **RoPE** | Length-generalizable, no learned embeddings |
| Normalization | **RMSNorm** | Faster than LayerNorm, no mean subtraction |
| Optimizer | **AdamW** | Decoupled weight decay, best for transformers |
| Objective | **Next-token prediction** | Standard language model pre-training |

---

## TezzMind Nano (Default)

The smallest current configuration fits in single-digit MB for weights:

```
vocab_size  = 256     (byte-level — every character is a token)
embed_dim   = 128
q_heads     = 4
kv_heads    = 2       (GQA ratio: 2:1)
head_dim    = 32      (= embed_dim / q_heads)
layers      = 4
ffn_hidden  = 384     (3× embed_dim — SwiGLU)
max_seq_len = 256
parameters  = 853,120
RAM         = ~6.5 MB (f64 weights only)
```

---

## Quick Start

```bash
# 1. Compile and run the menu demo
tezzc run projects/tezzmind/main.tn

# 2. Check the source compiles cleanly
tezzc check projects/tezzmind/main.tn

# 3. Run the deterministic verification path
tezzc buildexe projects/tezzmind/verify.tn build/tezzmind_verify.exe --verify
build/tezzmind_verify.exe
```

---

## Modes

Run `main.tn` and choose a mode from the menu:

| Mode | Description |
|------|-------------|
| `--demo` | Build model, run forward pass, generate from random weights |
| `--train` | Train on built-in seed text (3000 steps, saves checkpoint) |
| `--chat` | Load checkpoint, run interactive Q&A loop |
| `--bench` | Benchmark: 100 forward passes, count tokens/sec |
| `--info` | Print info about saved checkpoint |

For CI or local proof without menu input, build and run `verify.tn`. It prints
checksums, top-token output, generation length, before/after loss, trainer
step, and checkpoint checksum validation.

---

## Architecture Deep Dive

### Grouped Query Attention (GQA)

Standard multi-head attention has one K and V matrix per query head.
GQA groups multiple query heads to share a single K, V pair:

```
q_heads = 4,  kv_heads = 2
Q heads 0,1 → KV head 0
Q heads 2,3 → KV head 1
```

This reduces KV cache memory by the GQA ratio (2× in TezzMind Nano),
while preserving full expressivity in the query space.

### SwiGLU Feed-Forward

Each transformer layer has a gated FFN:

```
gate = linear(x, W_gate)   // shape: [ffn_hidden]
up   = linear(x, W_up)     // shape: [ffn_hidden]
out  = silu(gate) * up      // element-wise gate
y    = linear(out, W_down)  // back to [embed_dim]
```

SwiGLU consistently outperforms ReLU and GELU in practice.

### RoPE (Rotary Position Embedding)

Instead of adding learned position embeddings, RoPE rotates Q and K
vectors in 2D planes based on position. This gives:
- **Length generalization**: works beyond training sequence length
- **Relative encoding**: attention scores depend on position *difference*

### RMSNorm

```
RMSNorm(x) = x / sqrt(mean(x²) + ε) * γ
```

No mean subtraction (unlike LayerNorm) — about 30% faster.
Used as pre-norm in each transformer block.

---

## File Structure

```
projects/tezzmind/
├── tezzmind.mod          Module definition
├── main.tn               Entry point (demo/train/chat/bench)
├── lib/
│   ├── mind.tn           Core model: mind_new, mind_forward, mind_generate
│   └── trainer.tn        Training engine: analytical backprop + AdamW
└── train_data/
    └── seed.txt          Built-in seed text for initial training
```

---

## Library API

### mind.tn

```
mind_new(vocab, dim, q_heads, kv_heads, layers, ffn, max_seq) → *float
    Allocate and initialize a new TezzMind model with Xavier weight init.

mind_forward(model, token_id, pos, logits) → int
    Run one transformer forward step at position `pos`.
    Outputs vocab_size logits into the `logits` buffer.
    Uses KV cache for O(1) autoregressive generation.

mind_generate(model, prompt, max_tokens, temp, seed) → str
    Generate up to max_tokens characters from a text prompt.
    temp=0.0 → greedy, temp=0.7 → creative sampling.
    Caller must free() the returned string.

mind_save(model, path) → int
    Save weights to a .tnw binary file.

mind_load(path) → *float
    Load weights from a .tnw file. Returns 0 on failure.

mind_info(model) → int
    Print the model card (architecture summary).

mind_free(model) → int
    Free all model memory.
```

### trainer.tn

```
trainer_new(n_weights, lr) → *float
    Create a trainer with AdamW state (m1, m2 moments).

trainer_train_text(model, trainer, text, steps, log_every, save_every, path) → float
    Train on raw text for `steps` gradient steps.
    Returns final average loss.

trainer_eval_loss(model, text, n_samples) → float
    Estimate loss on text using n_samples random positions.

trainer_set_lr(trainer, lr) → int
trainer_set_weight_decay(trainer, wd) → int
trainer_set_grad_clip(trainer, clip) → int
trainer_free(trainer) → int
```

---

## Extending TezzMind

### Scaling Up (TezzMind Small)

Change the config constants in `main.tn`:

```tn
let MIND_VOCAB:int   = 8192
let MIND_DIM:int     = 256
let MIND_QHEADS:int  = 8
let MIND_KVHEADS:int = 4
let MIND_LAYERS:int  = 6
let MIND_FFN:int     = 768
let MIND_SEQLEN:int  = 512
```

This gives a ~25M parameter model (~200MB RAM).

### Adding Your Own Training Data

1. Put your text file in `train_data/my_data.txt`
2. In `main.tn`, change:
   ```tn
   text:str = _get_seed_text()
   ```
   to:
   ```tn
   text:str = io.read_all("train_data/my_data.txt")
   ```

### Integrating with the TezzNative AI Stack

TezzMind uses the same slab-based float pointer convention as the core
`nn.tn`, `llm.tn`, and `llm_core.tn` libraries. You can:

- Use `nn.nn_gqa_attention` directly in your own layers
- Use `nn.nn_swiglu` for custom gated FFNs
- Use `nn.nn_adamw_step` for any parameter slab
- Save/load with `mind_save` / `mind_load`

---

## Language Core Extensions (nn.tn)

TezzMind required these new primitives added to `lib/nn.tn`:

| Function | Description |
|----------|-------------|
| `nn_swiglu(gate, up, out, n)` | SwiGLU gated FFN |
| `nn_gqa_attention(q, k, v, out, seq, q_heads, kv_heads, hdim, causal)` | Grouped Query Attention |
| `nn_rope_apply(x, seq_len, n_heads, head_dim, base)` | Apply RoPE in-place |
| `nn_cross_entropy(logits, target, grad_out, vocab)` | Cross-entropy + gradient |
| `nn_sample_topk(logits, vocab, temp, top_k, seed)` | Temperature + top-k sampler |
| `nn_adamw_step(params, grads, m1, m2, n, lr, step, β1, β2, ε, wd)` | AdamW optimizer |
| `nn_clip_grad_norm(grads, n, max_norm)` | Gradient clipping |
| `nn_zero_grad(grads, n)` | Zero gradient buffer |

---

## Philosophy

> **TezzNative is free for everyone.**
> **TezzMind is on-device AI that grows with the language.**

TezzMind exists to prove that:
1. A complete, modern AI architecture can be expressed in TezzNative
2. On-device AI does not require a Python ecosystem
3. Millions of developers can build AI without cloud dependency
4. TezzNative can express a full local AI prototype while the production path hardens

The model is intentionally small so it runs on **any** device — from a Raspberry Pi
to a high-end workstation. As TezzNative matures, TezzMind scales with it.

---

## License

TezzMind is part of TezzNative and is **free for everyone** under the same license.
See `LICENSE.txt` in the root of the TezzNative repository.
