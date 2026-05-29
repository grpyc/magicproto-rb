# frozen_string_literal: true

module Magicprotorb
  # Prepended onto Kernel so that a bare `require "magicprotorb/<proto>_pb"`
  # compiles and registers <proto>.proto at require time. This is the Ruby
  # counterpart to magicproto's sys.meta_path finder.
  #
  # Only names under "magicprotorb/" that end in "_pb" / "_services_pb" are
  # claimed; everything else (including the native extension and version file)
  # falls through to the real require via super.
  module RequireHook
    PREFIX = "magicprotorb/"
    MUTEX = Mutex.new
    @required = {}

    def require(name)
      handled = RequireHook.dispatch(name)
      handled.nil? ? super : handled
    end

    # Returns true (loaded now), false (already loaded), or nil (not ours).
    def self.dispatch(name)
      return nil unless name.is_a?(String) && name.start_with?(PREFIX)

      rest = name[PREFIX.length..]
      if rest.end_with?("_services_pb")
        proto = "#{rest.delete_suffix("_services_pb")}.proto"
        loader = :load_services
      elsif rest.end_with?("_pb")
        proto = "#{rest.delete_suffix("_pb")}.proto"
        loader = :load_messages
      else
        return nil
      end

      MUTEX.synchronize do
        return false if @required[name]

        Loader.public_send(loader, proto)
        @required[name] = true
      end
      true
    end
  end
end
