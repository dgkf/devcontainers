# devcontainers

An experiment in using containers as language runtime executables

## Get Started

1. Clone the repo
2. Make language scripts executable (if they aren't already)
3. Add `/launchers` to your `PATH`
4. Try out a language runtime

## Goals

- Local-like executable, providing persistent storage for things like package
  libraries and full access to the user's home directory.
- Quick and easy set-up of language runtimes
- Relatively engine agnostic (`podman` default with `docker` fallback)
- Leverage publicly maintained images where possible, with minimal additions to
  make them operable as a local runtime.

## Project Status

The different available executables span a wide range of maturity, primarily
driven by which languages I spend the most time in. Contributions are welcome to
flesh them out further!

| Language | Commands | Maturity | Notes |
|---|---|---|---|
| R | `R` <br> `Rscript` | :large_blue_circle: :large_blue_circle: :large_blue_circle: :large_blue_circle: :black_circle: | graphics via web device using [`httpgd`](https://github.com/nx10/httpgd) |
| Julia | `julia` | :large_blue_circle: :large_blue_circle: :large_blue_circle: :black_circle: :black_circle: | needs a web-based display target, but I haven't explored it extensively | 
| Python | `python` <br> `pylsp` | :large_blue_circle: :large_blue_circle: :black_circle: :black_circle: :black_circle: | |
| JS | `node` <br>`npm` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |
| Rust | `rust` <br> `rustfmt` <br> `rustc` <br> `rust-analyzer` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | language server crashes frequently |
| Prolog | `prolog` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |
| APL | `apl` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |
| Go | `go` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |
| Java | `jdk` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |
| C | `clangd` | :large_blue_circle: :black_circle: :black_circle: :black_circle: :black_circle: | |

## Customizations

Generally, the executables should behave like a local executable. There are a
few flags that provide extra functionality to work with the containers
themselves.

Use `--` to provide your own `CMD`. For example, it's often handy to step into a
shell in the container:

```
R -- bash
```

To help minimize paramter conflicts with runtime executables, script flags are
prefixed with `---`. Common flags include `---build` to force the image to 
re-build, and `---echo` to output the full container launch command.

```
R ---build ---echo
```
