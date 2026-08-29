Build core module:

```sh
zig build-exe ./examples/calculator.zig \
    -target wasm32-freestanding \
    -fno-entry \
    -O ReleaseSmall \
    -rdynamic \
    -femit-bin=calculator.core.wasm
```

Embed WIT:

```sh
wasm-tools component embed ./examples/calculator.wit \
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

## Helpful commands

### Test component

```sh
wasmtime --invoke 'add(123, 456)' calculator.component.wasm
wasmtime --invoke 'multiply(123, 456)' calculator.component.wasm
```

### Generate dummy component

```sh
wasm-tools component embed ./wit/calculator.wit \
    --world calculator \
    --dummy \
    -o expected.wasm
```
