# 🌌 TezzNative 2.0 — Production Systems Programming Language

TezzNative is a next-generation, high-performance, developer-friendly systems programming language designed for the year 2026 and beyond. It combines the speed and control of C/C++ with modern syntax shortcuts, strict safety guarantees, embedded database engines, native graphics compositors, neural networking, real-time voice, and bare-metal HAL controllers.

This is the public distribution repository of TezzNative. It contains the official **TezzNative Standard Library (`lib/`)**, the self-contained Windows setup installer, and the official **VS Code Editor Support Extension (`tezznative-vscode`)**.

---

## 🚀 Key Highlights

*   ⚡ **Zero-Overhead Compilation & JIT**: LOWERED directly to optimized machine code (x86_64 and arm64). Supports instant JIT execution via `tezz run`.
*   🚀 **GB/TB/PB Scale Big I/O**: Zero-copy memory-mapped file streams, asynchronous IOCP (Windows) and `io_uring` (Linux) backends.
*   📊 **TezzDB Native B+ Tree Database**: Page-based embedded database with Write-Ahead Logging (WAL) for ACID transactions, compound 64-bit indices, and a built-in SQL-like Query Language (`TezzDBQL`).
*   🎨 **Pixel-Native Compositor & GUI Toolkit**: Immediate-mode windows, focusing loops, alpha blended transparency compositing, custom widgets, and SIMD blends.
*   🧠 **Transformer Neural Network Stack**: sinuses Prosodies, attention loops (`nn.tn`), BPE Tokenizer maps (`tokenizer.tn`), and slab-allocated LLM sampler inference steps (`llm.tn`).
*   🔊 **Real-time Voice Synthesis & Capture**: Multi-formant additive Text-to-Speech (TTS) synthesizer and neural Whisper-style Speech-to-Text (STT) transcriber.
*   🔌 **Embedded Bare-Metal HAL**: Full digital/analog GPIO, PWM, I2C, SPI, and UART drivers for AVR (Arduino Uno) and ARM Cortex-M (Raspberry Pi bare-metal).

---

## 🛠 VS Code Editor Support Extension

The official **`tezznative-vscode`** extension is bundled directly with the release and provides:
1.  ✨ **Syntax Highlighting**: Complete TextMate grammar rules for all variables, strings, string interpolations (`f"..."`), comments, keywords, control flows, and structural types.
2.  📝 **Smart Code Snippets**: Quick autocomplete templates for standard definitions (`fn`, `struct`), WebSocket servers, parameterized SQL queries, GUI buttons, and audio loops.
3.  📡 **Language Server Protocol (LSP)**: Integrates automatically with the compiler's built-in LSP engine (`tezzc lsp`) to provide real-time syntax checking, hover tooltips, and completions.

To install, simply copy or link the `tezznative-vscode` directory to your `.vscode/extensions/` folder.

---

## 📖 Syntax & Language Reference

### 1. Variables and Type Inference
Type declarations are strict but support modern syntax:
```python
let x:int = 42
let msg:str = "Hello"
let pi:float = 3.14159
```

### 2. Control Flow & Pattern Matching
```python
// Standard ranges and loops
for x in collection:
  say "Item: ", x

// Advanced Pattern Matching
match command {
  1 => say "Start"
  2 => say "Stop"
  _ => say "Unknown"
}
```

### 3. Error Handling & Result Propagation
Use `try-catch` structures with the `?` operator for clean, memory-safe error propagation:
```python
fn read_config(path:str) -> Result[str]:
  f:*BFile = bigfile_open(path, "r")?
  // ... read logic ...
  ret Ok(content)
```

---

## 📦 Standard Library Subsystem References

### 1. TezzServe Web API & WebSockets (`lib/tezzserve.tn`)
Create highly parallel HTTP/2 web APIs with WebSocket upgrades, CORS middlewares, and static directory servers:
```python
import "net"
import "tezzserve"

fn main() -> int:
  unsafe:
    srv:*HttpServer = tezzserve.server_new(8080)
    
    // Register WebSocket Route
    tezzserve.serve_ws_upgrade(srv, "/chat", fn(sock:*Socket, req:*Request) -> int:
      unsafe:
        say "Client connected to WebSocket!"
        tezzserve.serve_json(sock, 200, "{\"status\":\"connected\"}")
      ret 0
    )
    
    tezzserve.server_listen(srv)
    ret 0
```

### 2. TezzDBQL Parameterized Database Queries (`lib/tezzdbql.tn`)
Interact with the embedded B+ Tree database safely using parameterized SQL-like queries:
```python
import "tezzdb"
import "tezzdbql"

fn main() -> int:
  unsafe:
    db:*DB = tezzdb.db_open("records.db")
    
    // Parameterized INSERT
    params:[str;2]
    params[0] = "Alice"
    params[1] = "Developer"
    tezzdbql.db_exec2(db, "INSERT INTO users (name, role) VALUES (?, ?)", &params[0])
    
    // Index-aware SELECT Cursor
    cur:*DBCursor = tezzdbql.db_query(db, "SELECT * FROM users WHERE role = ?", &params[1], 1)
    while tezzdbql.cursor_next(cur) != 0:
      name:str = tezzdbql.cursor_field_str(cur, "name")
      say "User: ", name
      free(name)
      
    tezzdbql.cursor_free(cur)
    tezzdb.db_close(db)
    ret 0
```

### 3. Neural LLM Inference & Sampling (`lib/llm.tn`)
Run local, optimized transformer models natively using struct-free memory slabs and advanced temperature/nucleus samplers:
```python
import "llm"
import "tokenizer"

fn main() -> int:
  unsafe:
    // Load local LLM model weights and BPE tokenizer
    model:*float = llm.llm_load("tezz_tiny.tnw")
    tok:*Tokenizer = tokenizer.tokenizer_load("vocab.json", "merges.txt")
    
    logits:*float = malloc(1000 * 8) as *float
    llm.llm_forward_step(model, 5, 0, logits) // forward pass on token 5 at step 0
    
    // Temperature + Top-K + Top-P (Nucleus) sampling
    next_token:int = llm.llm_sample(logits, 1000, 0.8, 50, 0.9)
    say "Sampled Token: ", next_token
    
    free(logits as *char)
    llm.llm_free(model)
    tokenizer.tokenizer_free(tok)
    ret 0
```

### 4. Formant TTS Audio Playback (`lib/tts.tn`)
Generate real-time speech directly from text and play it synchronously through local speakers:
```python
import "tts"

fn main() -> int:
  unsafe:
    eng:*TtsEngine = tts.tts_new()
    tts.tts_set_voice(eng, "en-female")
    
    // Play speech directly via the OS Wave/MCI audio API
    tts.tts_speak(eng, "Hello! Welcome to the premium TezzNative SYSTEMS runtime.")
    
    tts.tts_free(eng)
    ret 0
```

---

## 🛠 Installation & Quickstart

1.  **Download the SDK Installer**: Download `TezzNativeSetup.exe` from our latest GitHub Releases page.
2.  **Execute the Installer**: Run `TezzNativeSetup.exe`. This installs the compiler `tezzc.exe`, the command CLI wrapper `tezz.exe`, and embeds all 50 standard library modules directly.
3.  **Compile & Execute**:
    ```bash
    // Run direct JIT:
    tezz run my_script.tn
    
    // Build optimized release binary:
    tezz build my_program.tn
    ```

---

## 💎 Corporate Branding & Support
TezzNative is a production-grade systems language proudly engineered and sponsored by **TezzCorp**. All release channels and IDE interfaces are stamped with the official **TezzCorp logo**.
