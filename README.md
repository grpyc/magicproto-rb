# magicprotorb

Import `.proto` files directly in Ruby. No `protoc`, no generated `_pb.rb` files, no build step:

```ruby
require "magicprotorb"                          # installs the import hook
require "magicprotorb/greet/hello_pb"           # compiles greet/hello.proto
require "magicprotorb/greet/hello_services_pb"  # + synthesizes the gRPC stub

req  = Greet::HelloRequest.new(name: "world")
stub = Greet::Greeter::Stub.new("localhost:50051", :this_channel_is_insecure)
```

`require "magicprotorb/greet/hello_pb"` compiles `greet/hello.proto` (found on
`MAGICPROTORB_PATH` / `$LOAD_PATH`) at require time and defines the message
constants. The dotted require path mirrors the canonical proto path 1:1, so the
require name, the file location, and the descriptor name can never drift apart —
the classic "the generated import points at the wrong place" problem cannot occur.

## How it works

A `Kernel#require` hook claims names under `magicprotorb/` that end in `_pb` or
`_services_pb` (only).

- `magicprotorb/greet/hello_pb` → canonical `greet/hello.proto`, located on the
  include roots (the `protoc -I` model: `MAGICPROTORB_PATH` then `$LOAD_PATH`).
- A small Rust extension (`magicprotorb_native`, built on the pure-Rust
  [`protox`](https://crates.io/crates/protox) compiler) turns the `.proto` into a
  serialized `FileDescriptorSet` — the one thing the stock protobuf runtime can't
  do itself.
- Those descriptors are registered through the stock
  `Google::Protobuf::DescriptorPool.generated_pool#add_serialized_file`, and the
  message/enum constants are assigned exactly the way a generated `_pb.rb` does,
  so the message classes are indistinguishable from generated ones.
- `_services_pb` modules are synthesized directly from the service descriptors as
  ordinary `GRPC::GenericService` classes (`require "grpc"` happens lazily).

See [DESIGN.md](DESIGN.md) for the full rationale, the multi-package namespacing
model, and the limitations.

## Where to put protos

Put `foo/bar.proto` where you'd want `foo/bar.rb`, and import it as
`magicprotorb/foo/bar_pb`.

A library ships its protos as data inside its own `lib/` directory (already on
`$LOAD_PATH`); the directory name namespaces them, so two installed gems can't
collide.

### Finding your protos (include roots)

magicprotorb resolves a proto by its canonical path against the include roots —
`MAGICPROTORB_PATH` first, then `$LOAD_PATH` — exactly like `protoc -I`. Note that
Ruby does **not** put the current directory on `$LOAD_PATH`, so a proto sitting
next to your script isn't found automatically. Make its directory an include root:

```ruby
require "magicprotorb"
$LOAD_PATH.unshift __dir__         # this script's dir is now an include root
require "magicprotorb/keyvalue_pb" # resolves ./keyvalue.proto
```

or point `MAGICPROTORB_PATH` at it from the shell:

```sh
MAGICPROTORB_PATH="$PWD" ruby my_script.rb
```


## Naming

| require | compiles | gives you |
| --- | --- | --- |
| `magicprotorb/greet/hello_pb` | `greet/hello.proto` | `Greet::HelloRequest`, ... |
| `magicprotorb/greet/hello_services_pb` | `greet/hello.proto` | `Greet::Greeter::Service` / `::Stub` |

The proto `package` becomes the Ruby module path the same way `protoc`'s Ruby
generator does it: `package my_co.sub_pkg.v1;` → `MyCo::SubPkg::V1`.

There is also a programmatic API equivalent to the requires:

```ruby
Magicprotorb.import("greet/hello")           # like require "magicprotorb/greet/hello_pb"
Magicprotorb.import_services("greet/hello")  # like require "magicprotorb/greet/hello_services_pb"
Magicprotorb.include_paths                   # the roots currently searched
```

## Installation

```ruby
# Gemfile
gem "magicprotorb"
```

Building the gem compiles the bundled Rust extension, so a Rust toolchain
(`cargo`) is required at install time. The runtime needs only `google-protobuf`
(and `grpc`, if you import services).

### Installing from a local checkout

```sh
bundle exec rake install      # builds the gem and installs it (native ext included)
```

After this, `require "magicprotorb"` works from any script without `-I`. The gem
installs into whichever Ruby is active (`rbenv`/`rvm`), so install under the same
Ruby you'll run with.

> The `install` task deliberately runs `gem install` **outside** the bundle
> (`Bundler.with_unbundled_env`). A native-extension gem whose own gemspec is the
> bundle's path gem otherwise fails to build at install time, because RubyGems'
> per-extension build dir goes missing under `bundle exec`.

## Development

After checking out the repo:

```sh
bin/setup          # install dependencies
bundle exec rake   # compile the extension, then run the tests
```

`bundle exec rake compile` builds `ext/magicprotorb_native` into
`lib/magicprotorb/`. The fixture protos live in `test/protos`.
