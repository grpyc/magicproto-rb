# frozen_string_literal: true

module Magicprotorb
  # Translates proto identifiers into Ruby constant names exactly the way
  # protoc's Ruby generator does, so the constants magicprotorb synthesizes are
  # identical to those a checked-in `*_pb.rb` would define.
  #
  #   package my_co.sub_pkg.v1  ->  MyCo::SubPkg::V1
  #   message OuterMsg          ->  OuterMsg            (nested under its parent)
  #
  # Each dot-separated package segment is split on "_" and each part is
  # capitalized (my_co -> MyCo, v1 -> V1); message/enum names keep their own
  # casing with only the first letter forced upper.
  module Naming
    module_function

    # ["MyCo", "SubPkg", "V1"] for "my_co.sub_pkg.v1"; [] for an empty package.
    def package_modules(package)
      return [] if package.nil? || package.empty?

      package.split(".").map { |segment| camelize(segment) }
    end

    def camelize(segment)
      segment.split("_").map { |part| part.empty? ? "" : part[0].upcase + part[1..] }.join
    end

    # Constant name for a message/enum simple name (first letter upper).
    def constant_name(simple_name)
      simple_name[0].upcase + simple_name[1..]
    end
  end
end
