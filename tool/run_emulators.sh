#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Optional workaround for Java under Android/proot. Normal machines use Java
# directly. The shim is scoped to the emulator subprocess, never installed.
if [ "${AIKO_ANDROID_PROOT_JAVA:-0}" = 1 ]; then
  shim_dir="$PWD/.dart_tool/aiko-java"
  mkdir -p "$shim_dir/bin"
  java_binary=$(command -v java)
  cc -shared -fPIC -o "$shim_dir/exec_memory.so" tool/proot_java_exec_memory.c -ldl
  cat > "$shim_dir/bin/java" <<EOF
#!/bin/sh
exec env LD_PRELOAD="$shim_dir/exec_memory.so" "$java_binary" "\$@"
EOF
  chmod +x "$shim_dir/bin/java"
  PATH="$shim_dir/bin:$PATH"
  export PATH
  JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS:-'-Xmx512m -XX:+UseSerialGC'}
  export JAVA_TOOL_OPTIONS
fi

if [ ! -f firebase/functions/lib/index.js ]; then
  npm run functions:build
fi
if [ ! -f firebase/functions/.secret.local ]; then
  cp firebase/functions/.secret.local.example firebase/functions/.secret.local
fi
set -- --project demo-aiko --export-on-exit .firebase-data "$@"
if [ -f .firebase-data/firebase-export-metadata.json ]; then
  set -- --import .firebase-data "$@"
fi
exec node node_modules/firebase-tools/lib/bin/firebase.js emulators:start "$@"
