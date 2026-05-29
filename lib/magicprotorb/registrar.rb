# frozen_string_literal: true

require "google/protobuf"
require "google/protobuf/descriptor_pb"

module Magicprotorb
  # Takes a compiled FileDescriptorSet and registers it through the *stock*
  # protobuf machinery — DescriptorPool.generated_pool#add_serialized_file plus
  # the same constant assignments a generated `*_pb.rb` performs. The resulting
  # message classes are therefore indistinguishable from generated ones.
  module Registrar
    # The protobuf runtime already owns google/protobuf/*; never re-register or
    # assign constants for those (it would clobber Google::Protobuf::Timestamp
    # and friends, and add_serialized_file would reject the duplicate).
    WELL_KNOWN_PREFIX = "google/protobuf/"

    @loaded_files = {}

    module_function

    # Register every file in the set (dependency-ordered by the compiler), then
    # assign Ruby constants for each non-well-known file. Idempotent.
    def register(file_descriptor_set)
      pool = Google::Protobuf::DescriptorPool.generated_pool
      file_descriptor_set.file.each { |file| register_file(pool, file) }
    end

    def register_file(pool, file)
      name = file.name
      return if @loaded_files[name]

      begin
        pool.add_serialized_file(file.to_proto)
      rescue Google::Protobuf::TypeError => e
        # Already present (a well-known type, or a shared import registered by a
        # previously imported proto). Anything else is a real error.
        raise unless e.message.include?("duplicate file name")
      end

      @loaded_files[name] = true
      assign_constants(pool, file) unless name.start_with?(WELL_KNOWN_PREFIX)
    end

    # --- constant assignment (mirrors protoc's Ruby generator) ----------------

    def assign_constants(pool, file)
      package = file.package
      scope = ensure_module(Naming.package_modules(package))
      file.message_type.each { |msg| assign_message(pool, scope, package, msg) }
      file.enum_type.each { |enum| assign_enum(pool, scope, package, enum.name) }
    end

    def assign_message(pool, parent, scope_fullname, msg)
      full_name = qualify(scope_fullname, msg.name)
      klass = pool.lookup(full_name).msgclass
      set_const(parent, Naming.constant_name(msg.name), klass)

      # Synthetic map-entry messages get no constant (protoc skips them too).
      msg.nested_type.each do |nested|
        next if nested.options&.map_entry

        assign_message(pool, klass, full_name, nested)
      end
      msg.enum_type.each { |enum| assign_enum(pool, klass, full_name, enum.name) }
    end

    def assign_enum(pool, parent, scope_fullname, enum_name)
      full_name = qualify(scope_fullname, enum_name)
      set_const(parent, Naming.constant_name(enum_name), pool.lookup(full_name).enummodule)
    end

    # --- helpers --------------------------------------------------------------

    def qualify(scope, name)
      scope.nil? || scope.empty? ? name : "#{scope}.#{name}"
    end

    # Walk/create a chain of modules (e.g. %w[MyCo SubPkg V1]) under Object,
    # returning the innermost. An empty list returns Object (no-package case).
    def ensure_module(segments)
      segments.reduce(Object) do |parent, segment|
        if parent.const_defined?(segment, false)
          parent.const_get(segment, false)
        else
          mod = Module.new
          parent.const_set(segment, mod)
          mod
        end
      end
    end

    def set_const(parent, name, value)
      parent.const_set(name, value) unless parent.const_defined?(name, false)
    end
  end
end
