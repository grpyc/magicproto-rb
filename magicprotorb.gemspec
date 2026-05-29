# frozen_string_literal: true

require_relative "lib/magicprotorb/version"

Gem::Specification.new do |spec|
  spec.name = "magicprotorb"
  spec.version = Magicprotorb::VERSION
  spec.authors = ["Sam"]

  spec.summary = "Import .proto files directly in Ruby — no protoc, no generated _pb.rb, no build step."
  spec.description = <<~DESC
    magicprotorb lets you `require "magicprotorb/foo/bar_pb"` and have foo/bar.proto
    compiled to descriptors and registered at require time. The dotted require path
    mirrors the canonical proto path 1:1, so the require name, the file location, and
    the descriptor name can never drift apart. A small Rust extension (built on the
    pure-Rust protox compiler) turns .proto text into a FileDescriptorSet, which is
    then registered through the stock protobuf DescriptorPool — making the resulting
    message classes indistinguishable from generated ones.
  DESC
  spec.homepage = "https://github.com/sam/magicprotorb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # The Rust compiler extension. Built via rb_sys at install time.
  spec.extensions = ["ext/magicprotorb_native/extconf.rb"]

  # The stock protobuf runtime: we register descriptors through it and reuse its
  # descriptor.proto message classes to parse the FileDescriptorSet we compile.
  spec.add_dependency "google-protobuf", ">= 3.21", "< 5.0"

  # Build-time helper for the Rust extension (rb_sys/mkmf, used by extconf.rb).
  spec.add_dependency "rb_sys", "~> 0.9"

  # NOTE: gRPC support (the `..._services_pb` requires) is optional and loaded
  # lazily — `require "grpc"` only happens if you actually import a service.
  # It is intentionally NOT a hard dependency so message-only users stay lean.
end
