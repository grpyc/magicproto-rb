# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Point the include roots at the fixture protos before magicprotorb loads, so
# `require "magicprotorb/greet/hello_pb"` can find greet/hello.proto.
ENV["MAGICPROTORB_PATH"] = File.expand_path("protos", __dir__)

require "magicprotorb"

require "minitest/autorun"
