#!/bin/bash
# Compila y corre las pruebas de la lógica pura de Haru (sin interfaz ni procesos).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -target "$(uname -m)-apple-macos14.0" Sources/Logica/*.swift Tests/*.swift -o build/pruebas
./build/pruebas
