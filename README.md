Build core module:

```sh
zig build-exe src/calculator.zig \
    -target wasm32-freestanding \
    -fno-entry \
    -O ReleaseSmall \
    --export="cm32p2|example:calculator/operations|add" \
    --export="cm32p2|example:calculator/operations|multiply" \
    -femit-bin=calculator.core.wasm
```

> [!NOTE]
> Without `--export=func`, the functions were being optimized out.

Embed WIT:

```sh
wasm-tools component embed ./wit/calculator.wit \
    --world calculator \
    calculator.core.wasm \
    -o calculator.embedded.wasm
```

Create component:

```sh
wasm-tools component new \
    calculator.embedded.wasm \
    -o calculator.component.wasm
```

Test component:

```sh
wasmtime --invoke 'add(123, 456)' calculator.component.wasm
wasmtime --invoke 'multiply(123, 456)' calculator.component.wasm
```
