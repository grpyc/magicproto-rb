# Design

`magicprotorb` is the Ruby counterpart of [magicproto](https://example.com/magicproto)
(Python). The goal is identical: make a `.proto` file importable directly, with
no `protoc` invocation, no checked-in generated code, and no build step in your
edit/run loop. Only the host-language mechanics differ.

## The core idea

A generated protobuf file is a pure function of two things: the `.proto` source
and the path it lives at. Checking the output into your repo creates a third,
independent thing that has to be kept in sync by hand — and the failure mode
everyone has hit is the generated `require`/`import` pointing somewhere the
descriptor name doesn't actually live.

`magicprotorb` removes the third thing. The require path *is* the proto path:

```
require "magicprotorb/greet/hello_pb"   <->   greet/hello.proto
```

There is exactly one source of truth (the `.proto`), and the mapping between the
require name, the file on disk, and the descriptor's fully-qualified name is the
identity function. They cannot drift because there is nothing to keep in sync.

## The pipeline

```
require "magicprotorb/greet/hello_pb"
        │
        ▼
RequireHook        claim "magicprotorb/<x>_pb" / "<x>_services_pb"; strip suffix
        │           -> canonical proto path "greet/hello.proto"
        ▼
IncludePath        resolve against include roots (MAGICPROTORB_PATH, then $LOAD_PATH)
        │
        ▼
Compiler._compile  Rust ext (protox) -> serialized FileDescriptorSet  [the missing piece]
        │
        ▼
Registrar          decode FDS; add_serialized_file each file (dep order, idempotent);
        │           assign Ruby constants exactly as a generated _pb.rb would
        ▼
ServiceBuilder     (only for _services_pb) synthesize GRPC::GenericService + Stub
```

### Why a native extension at all

The stock `google-protobuf` runtime can *consume* a serialized
`FileDescriptorSet` (`DescriptorPool#add_serialized_file`) and it ships the
descriptor.proto message types (`Google::Protobuf::FileDescriptorSet` et al.) —
but it cannot *produce* descriptors from `.proto` text. Compiling `.proto` is
precisely the job of `protoc`.

`magicprotorb` does that one step with [`protox`](https://crates.io/crates/protox),
a pure-Rust protobuf compiler, wrapped in a tiny [`magnus`](https://crates.io/crates/magnus)
extension (`ext/magicprotorb_native`). The extension exposes a single method:

```ruby
Magicprotorb::Compiler._compile(proto_path, include_dirs) # => String (serialized FileDescriptorSet)
```

Everything above that line is ordinary Ruby talking to the ordinary protobuf
runtime. This mirrors magicproto, which wraps the same `protox` crate.

### Why constants are assigned by hand

`add_serialized_file` registers descriptors in the pool but does **not** create
any Ruby constants — a generated `_pb.rb` is what does
`HelloRequest = pool.lookup("greet.HelloRequest").msgclass`. So the `Registrar`
walks the `FileDescriptorProto` and performs the same assignments, byte-for-byte
compatible with `protoc`'s Ruby generator:

- `package a_b.c` → nested modules `A_b`-style camelization → `AB::C`
  (each `_`-delimited part of each segment is capitalized: `my_co` → `MyCo`).
- messages → `lookup(full_name).msgclass`, nested messages under their parent
  constant (`Book::Chapter`).
- enums → `lookup(full_name).enummodule`.
- synthetic `map<>` entry messages get no constant (protoc skips them too).

The result is genuinely the same class you'd get from generated code — same
descriptor object, same `#encode`/`#decode`, same `.name`.

## Multi-package / namespacing model

Two independent axes, deliberately kept separate:

1. **File location** is what you import and what `protoc -I` resolves. It is
   *not* required to match the proto `package`. Put `foo/bar.proto` where you'd
   put `foo/bar.rb` and import `magicprotorb/foo/bar_pb`.

2. **Proto `package`** is what determines the Ruby module nesting of the
   resulting constants, via the protoc naming rule above.

Because the include roots are `MAGICPROTORB_PATH` then `$LOAD_PATH`, a gem ships
its protos under its own `lib/` and the **directory name namespaces them**: gem
`acme` ships `lib/acme/widgets.proto`, you `require "magicprotorb/acme/widgets_pb"`,
and a second gem physically cannot shadow it without colliding on the same
directory. This is the `protoc -I` include model, reused verbatim.

### Imports

Compiling `greet/hello.proto` compiles its transitive imports too; every file in
the returned `FileDescriptorSet` is registered into the pool (in dependency
order, idempotently). Constants are also assigned for imported, non-well-known
files, matching `protoc`'s behavior of emitting `require`s for each dependency.
Well-known types (`google/protobuf/*`) are owned by the runtime and are neither
re-registered nor re-named.

## gRPC

`require "magicprotorb/greet/hello_services_pb"` first does the message load
(register + constants), then reads the service descriptors of *that file only*
(matching `protoc`'s per-file output) and builds, for each service:

```ruby
module Greet
  module Greeter
    class Service
      include GRPC::GenericService
      self.marshal_class_method   = :encode
      self.unmarshal_class_method = :decode
      self.service_name = "greet.Greeter"
      rpc :SayHello, Greet::HelloRequest, Greet::HelloReply
      rpc :SayHelloStream, Greet::HelloRequest, stream(Greet::HelloReply)
    end
    Stub = Service.rpc_stub_class
  end
end
```

`require "grpc"` is lazy, so message-only users never load it. Streaming sides
are wrapped with the DSL's `stream(...)`, exactly as generated code does.

## Idempotency & concurrency

- Compilation results are memoized per canonical proto path.
- `add_serialized_file` rejects duplicate file names; the `Registrar` tracks
  loaded files and also rescues that specific error, so re-requiring, shared
  imports, and pre-registered well-known types are all no-ops.
- A re-`require` of an already-loaded module returns `false`, like `Kernel#require`.
- A process-wide mutex serializes the pool mutations.

## Limitations

- **A compiler is needed at *install* time.** The Rust extension is compiled
  when the gem installs (a Rust toolchain / `cargo` must be present). The point
  of magicprotorb is removing `protoc` from your *edit/run* loop, not removing
  all native build steps; the trade is "compile a small Rust crate once at
  install" for "never run protoc again."
- **Constants appear at require time, not parse time.** Editors/static analyzers
  that don't execute the require won't see `Greet::HelloRequest`. This is
  inherent to runtime code generation (same caveat as magicproto).
- **The hook only claims `magicprotorb/…_pb` / `…_services_pb`.** Anything else
  (including the native extension and the version file) falls straight through to
  the real `require`.
- **One descriptor pool.** Everything registers into
  `DescriptorPool.generated_pool`, exactly like generated code; two different
  protos defining the same fully-qualified type still conflict, just as they
  would with `protoc`.
- **`required_ruby_version >= 3.0`**; descriptor types are loaded via
  `google/protobuf/descriptor_pb`, which is required explicitly for compatibility
  with protobuf 4.x where it is not auto-loaded.
