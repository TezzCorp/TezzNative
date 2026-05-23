# <p align="center"><img src="https://raw.githubusercontent.com/TezzCorp/TezzNative/main/tezznative-vscode/tezzcorp-logo.png" alt="TezzCorp Logo" width="128"/></p>

# <p align="center">🌌 TezzNative Language Support</p>

<p align="center">
  <b>Premium Syntax Highlighting, Smart Snippets, and LSP Integration for TezzNative 2.0</b>
</p>

---

**TezzNative** is a next-generation, high-performance systems programming language designed by **TezzCorp**. This official extension provides first-class support for TezzNative in Visual Studio Code, ensuring a premium, responsive, and productive development experience.

---

## 💎 Features

### 1. ✨ Precision Syntax Highlighting
A robust, highly optimized TextMate grammar engine that highlights every detail of the TezzNative language:
*   **Keywords & Control Flow**: Strict types, loop patterns, pattern matches, error-aware functions, and JIT primitives.
*   **Strings & Interpolations**: Seamless highlighting of normal strings and formatted interpolated strings (`f"..."`).
*   **Variable Bindings & Literals**: Distinct coloring for type assertions (`let x:int`), scientific floating points, and memory pointers.

### 2. 📝 Production-Ready Code Snippets
Get up to speed immediately with our high-productivity autocompletion templates:
*   `fn` — Function definitions with return type signatures.
*   `struct` — Custom data records.
*   `serve_ws_upgrade` — Highly-concurrent HTTP/2 WebSocket upgrade handlers (`tezzserve`).
*   `db_query` — ACID-compliant B+ Tree database cursor lookups (`tezzdbql`).
*   `tts` / `stt` — Formant audio synthesis and microphone voice-recognition loops.

### 3. 📡 Native Language Server (LSP) Bridge
Bootstrap the compiler's built-in language server (`tezzc lsp`) directly from VS Code to enable:
*   Real-time semantic error detection and red underlines.
*   Hover documentation tooltips for standard library modules.
*   Smart autocompletion for struct fields and namespace variables.

---

## 🛠 Quickstart Guide

1.  **Install the Extension**: Install this extension directly from the VS Code Marketplace.
2.  **Install TezzNative SDK**: Download and run the `TezzNativeSetup.exe` installer from the [Official GitHub Releases](https://github.com/TezzCorp/TezzNative).
3.  **Start Coding**: Create a new file with the `.tn` or `.tnx` extension. VS Code will instantly recognize it as a TezzNative file, display the official **TezzCorp** file icon, and activate syntax highlighting!

---

## 📦 Bundled standard library Support
Provides autocomplete and LSP hooks for all 50+ core standard library modules, including:
*   `std`, `io`, `str`, `math`, `os`, `sys`, `time` (Core systems layers)
*   `tezzdb`, `tezzdbql` (ACID B+ Tree SQL engine)
*   `tezzserve` (HTTP/2 & WebSocket web server)
*   `llm`, `nn`, `tokenizer` (Transformer Neural network stack)
*   `tts`, `stt` (Real-time Speech Synthesis & microphone transcribers)

---

## 🛡 License
© 2026 TezzCorp Pvt Ltd. All Rights Reserved. Engineered and Sponsored by **Rohit Pathak**, Director of TezzCorp Pvt Ltd.
Licensed under the [TezzCorp Private Source License (TPSL v1.0)](https://github.com/TezzCorp/TezzNative/blob/main/LICENSE.txt).
