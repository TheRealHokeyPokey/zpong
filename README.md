# Readme

This is an experimental multiplayer Pong game written in Zig, using SDL3. It can be played locally on a single machine, or over LAN.

## Build (optimized)

```sh
zig build -Doptimize=fast
```

## Run (local multiplayer)

```sh
./zig-out/bin/zpong
```

## Run (LAN host)

```sh
./zig-out/bin/zpong --type=host --host-port=55555 --no-localhost 
```

## Run (LAN client)

```sh
./zig-out/bin/zpong --type=client --host-ip=X.X.X.X:55555
```

## Build options

```sh
zig build --help
```

## Run options

```sh
./zig-out/bin/zpong --help
```

## Supported Platforms

- Linux with Wayland
