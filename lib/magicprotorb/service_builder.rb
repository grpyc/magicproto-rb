# frozen_string_literal: true

module Magicprotorb
  # Synthesizes gRPC Service/Stub classes from the service descriptors in a
  # FileDescriptorProto — the runtime equivalent of a generated
  # `*_services_pb.rb`. Requires the optional `grpc` gem, loaded lazily so that
  # message-only users never pay for it.
  module ServiceBuilder
    module_function

    def build(file)
      require "grpc"
      package = file.package
      file.service.each { |service| build_service(package, service) }
    end

    def build_service(package, service)
      # Use to_h to read the repeated `method` field: ServiceDescriptorProto#method
      # collides with Ruby's Object#method.
      descriptor = service.to_h
      name = descriptor[:name]
      full_name = qualify(package, name)

      service_class = define_service_class(full_name, descriptor[:method] || [])

      mod = Registrar.ensure_module(Naming.package_modules(package) + [Naming.constant_name(name)])
      mod.const_set(:Service, service_class) unless mod.const_defined?(:Service, false)
      mod.const_set(:Stub, service_class.rpc_stub_class) unless mod.const_defined?(:Stub, false)
    end

    def define_service_class(full_name, methods)
      pool = Google::Protobuf::DescriptorPool.generated_pool

      Class.new do
        include GRPC::GenericService

        self.marshal_class_method = :encode
        self.unmarshal_class_method = :decode
        self.service_name = full_name

        methods.each do |method|
          request = pool.lookup(ServiceBuilder.strip(method[:input_type])).msgclass
          response = pool.lookup(ServiceBuilder.strip(method[:output_type])).msgclass
          # stream(...) is provided by GenericService's DSL inside the class body.
          request = stream(request) if method[:client_streaming]
          response = stream(response) if method[:server_streaming]
          rpc method[:name].to_sym, request, response
        end
      end
    end

    def qualify(package, name)
      package.nil? || package.empty? ? name : "#{package}.#{name}"
    end

    # Descriptor type references are fully-qualified with a leading dot
    # (".greet.HelloRequest"); the pool is keyed without it.
    def strip(type_name)
      type_name.sub(/\A\./, "")
    end
  end
end
