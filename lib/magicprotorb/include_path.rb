# frozen_string_literal: true

module Magicprotorb
  # Resolves canonical proto paths against include roots, mirroring the
  # `protoc -I` model: MAGICPROTORB_PATH first, then Ruby's $LOAD_PATH.
  #
  # This is the Ruby analogue of magicproto's "MAGICPROTO_PATH then sys.path":
  # a library ships its protos as package data under its own lib directory, that
  # directory is already on $LOAD_PATH, and the directory name namespaces the
  # protos so two installed gems can't collide.
  module IncludePath
    ENV_VAR = "MAGICPROTORB_PATH"

    module_function

    # Ordered, de-duplicated list of existing directories to search, highest
    # priority first. These become the `-I` include roots handed to the compiler.
    def roots
      raw = []
      if (env = ENV.fetch(ENV_VAR, nil)) && !env.empty?
        raw.concat(env.split(File::PATH_SEPARATOR))
      end
      raw.concat($LOAD_PATH)

      seen = {}
      raw.each_with_object([]) do |dir, out|
        next if dir.nil? || dir.to_s.empty?

        path = File.expand_path(dir.to_s)
        next if seen[path] || !File.directory?(path)

        seen[path] = true
        out << path
      end
    end

    # The first root under which +proto_path+ exists, or nil. Used to produce a
    # LoadError-shaped failure before invoking the compiler.
    def resolve(proto_path)
      roots.find { |root| File.file?(File.join(root, proto_path)) }
    end
  end
end
