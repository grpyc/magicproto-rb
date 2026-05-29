//! The native half of magicprotorb.
//!
//! Exactly one job: take a canonical proto path plus a list of include roots
//! (the `protoc -I` model) and return a *serialized `FileDescriptorSet`* — the
//! same bytes a `protoc --descriptor_set_out` invocation would emit, and the
//! same bytes the stock Ruby protobuf runtime knows how to register via
//! `DescriptorPool#add_serialized_file`.
//!
//! The compiler is `protox`, a pure-Rust protobuf compiler, so there is no
//! dependency on a `protoc` binary at run time.

use magnus::{function, prelude::*, Error, RString, Ruby};
use prost::Message;

/// Compile `file` (resolved against `includes`) and return the serialized
/// `FileDescriptorSet`, transitive dependencies included, as a binary string.
fn compile(ruby: &Ruby, file: String, includes: Vec<String>) -> Result<RString, Error> {
    let fds = protox::compile([file], includes).map_err(|e| {
        Error::new(
            ruby.exception_runtime_error(),
            format!("magicprotorb: failed to compile proto: {e}"),
        )
    })?;
    Ok(RString::from_slice(&fds.encode_to_vec()))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Magicprotorb")?;
    let compiler = module.define_class("Compiler", ruby.class_object())?;
    // Underscore-prefixed: the Ruby Compiler wrapper adds path resolution and
    // error context on top of this raw call.
    compiler.define_singleton_method("_compile", function!(compile, 2))?;
    Ok(())
}
