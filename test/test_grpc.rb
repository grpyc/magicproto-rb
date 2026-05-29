# frozen_string_literal: true

require "test_helper"
require "grpc"

class TestGrpc < Minitest::Test
  def setup
    require "magicprotorb/greet/hello_services_pb"
  end

  def test_service_class_is_a_generic_service
    assert_includes Greet::Greeter::Service.ancestors, GRPC::GenericService
    assert_equal "greet.Greeter", Greet::Greeter::Service.service_name
  end

  def test_stub_is_a_client_stub
    assert_operator Greet::Greeter::Stub, :<, GRPC::ClientStub
  end

  def test_unary_rpc_is_registered_with_message_classes
    desc = Greet::Greeter::Service.rpc_descs.fetch(:SayHello)
    assert_equal Greet::HelloRequest, desc.input
    assert_equal Greet::HelloReply, desc.output
  end

  def test_server_streaming_rpc_is_wrapped_in_stream
    desc = Greet::Greeter::Service.rpc_descs.fetch(:SayHelloStream)
    # A server-streaming output is wrapped, not the bare message class.
    refute_equal Greet::HelloReply, desc.output
    assert desc.server_streamer?
    refute desc.client_streamer?
  end
end
