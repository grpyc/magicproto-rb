# frozen_string_literal: true

module Magicprotorb
  # Orchestrates a single import: resolve -> compile -> register (-> services).
  # Compilation results are memoized per canonical proto path; a process-wide
  # mutex serializes the descriptor-pool mutations.
  module Loader
    MUTEX = Mutex.new
    @compiled = {}

    module_function

    # Register messages/enums for +proto_path+ (and its imports). Idempotent.
    def load_messages(proto_path)
      MUTEX.synchronize { Registrar.register(compile(proto_path)) }
    end

    # As load_messages, plus synthesize gRPC Service/Stub for the proto's own
    # services (not those of its imports — matching protoc's per-file output).
    def load_services(proto_path)
      MUTEX.synchronize do
        fds = compile(proto_path)
        Registrar.register(fds)
        primary = fds.file.find { |file| file.name == proto_path } || fds.file.last
        ServiceBuilder.build(primary)
      end
    end

    # Compile +proto_path+ to a FileDescriptorSet via the native protox-backed
    # compiler, using the current include roots. Memoized.
    def compile(proto_path)
      @compiled[proto_path] ||= begin
        if IncludePath.resolve(proto_path).nil?
          raise LoadError,
                "magicprotorb: cannot find #{proto_path} on #{IncludePath::ENV_VAR} or $LOAD_PATH"
        end

        bytes =
          begin
            Compiler._compile(proto_path, IncludePath.roots)
          rescue StandardError => e
            raise CompileError, e.message
          end

        Google::Protobuf::FileDescriptorSet.decode(bytes)
      end
    end
  end
end
