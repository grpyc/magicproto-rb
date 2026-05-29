# frozen_string_literal: true

require "test_helper"

class TestMagicprotorb < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Magicprotorb::VERSION
  end

  def test_imports_messages_and_assigns_named_constants
    require "magicprotorb/greet/hello_pb"

    req = Greet::HelloRequest.new(name: "world")
    assert_equal "world", req.name
    # Indistinguishable from a generated class: it has a real constant name.
    assert_equal "Greet::HelloRequest", Greet::HelloRequest.name
  end

  def test_message_roundtrips_through_the_stock_runtime
    require "magicprotorb/greet/hello_pb"

    bytes = Greet::HelloReply.encode(Greet::HelloReply.new(message: "hi"))
    assert_equal "hi", Greet::HelloReply.decode(bytes).message
  end

  def test_dotted_package_maps_to_nested_modules
    require "magicprotorb/example/v1/library_pb"

    assert_kind_of Class, Example::V1::Book
    assert_equal "Example::V1::Book", Example::V1::Book.name
  end

  def test_nested_message_enum_and_map
    require "magicprotorb/example/v1/library_pb"

    book = Example::V1::Book.new(
      title: "Proto Magic",
      genre: :FICTION,
      word_counts: { "intro" => 120 },
      chapters: [Example::V1::Book::Chapter.new(title: "Ch1", pages: 10)]
    )

    assert_equal :FICTION, book.genre
    assert_equal 120, book.word_counts["intro"]
    assert_equal "Ch1", book.chapters.first.title
    # Nested message constant lives under its parent, like generated code.
    assert_equal "Example::V1::Book::Chapter", Example::V1::Book::Chapter.name
    # Enum is an enummodule, not a class.
    assert_equal 1, Example::V1::Genre.resolve(:FICTION)
  end

  def test_imports_are_registered_transitively
    # library.proto imports types.proto; requiring the former must make the
    # imported Author/Genre usable (descriptors registered + constants assigned).
    require "magicprotorb/example/v1/library_pb"

    author = Example::V1::Author.new(name: "Sam")
    book = Example::V1::Book.new(title: "t", author: author)
    assert_equal "Sam", book.author.name
  end

  def test_require_is_idempotent
    require "magicprotorb/greet/hello_pb"
    # A second require of the same proto is a no-op and returns false, exactly
    # like Kernel#require for an already-loaded file.
    assert_equal false, require("magicprotorb/greet/hello_pb")
  end

  def test_non_proto_names_fall_through_to_real_require
    # Does not end in _pb, so the hook must not claim it — it reaches the real
    # require, which raises LoadError for a nonexistent file.
    assert_raises(LoadError) { require "magicprotorb/definitely/not/a/proto/module" }
  end

  def test_missing_proto_raises_load_error
    assert_raises(LoadError) { require "magicprotorb/nope/missing_pb" }
  end

  def test_invalid_proto_raises_compile_error
    error = assert_raises(Magicprotorb::CompileError) { require "magicprotorb/broken/bad_pb" }
    refute_empty error.message
  end

  def test_programmatic_import_api
    Magicprotorb.import("greet/hello")
    assert Greet::HelloRequest

    assert_includes Magicprotorb.include_paths, File.expand_path("protos", __dir__)
  end
end
