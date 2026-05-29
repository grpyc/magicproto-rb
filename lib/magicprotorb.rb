# frozen_string_literal: true

require "google/protobuf"
require "google/protobuf/descriptor_pb"

require_relative "magicprotorb/version"

module Magicprotorb
  class Error < StandardError; end

  # Raised when the native compiler rejects a .proto (syntax error, unresolved
  # import, etc.).
  class CompileError < Error; end
end

# The Rust compiler extension (defines Magicprotorb::Compiler._compile).
require_relative "magicprotorb/magicprotorb_native"

require_relative "magicprotorb/naming"
require_relative "magicprotorb/include_path"
require_relative "magicprotorb/registrar"
require_relative "magicprotorb/service_builder"
require_relative "magicprotorb/loader"
require_relative "magicprotorb/require_hook"

module Magicprotorb
  # Public, programmatic entry points. The primary interface is the require hook
  # installed below; these mirror it for callers who prefer an explicit API.

  module_function

  # The include roots currently searched for protos (MAGICPROTORB_PATH then
  # $LOAD_PATH), highest priority first.
  def include_paths
    IncludePath.roots
  end

  # Programmatic equivalent of `require "magicprotorb/<proto>_pb"`. Accepts a
  # canonical proto path with or without the .proto extension.
  def import(proto)
    Loader.load_messages(normalize(proto))
  end

  # Programmatic equivalent of `require "magicprotorb/<proto>_services_pb"`.
  def import_services(proto)
    Loader.load_services(normalize(proto))
  end

  def normalize(proto)
    proto.end_with?(".proto") ? proto : "#{proto}.proto"
  end
end

# Install the import hook. After this, `require "magicprotorb/foo/bar_pb"` works.
Kernel.prepend(Magicprotorb::RequireHook)
