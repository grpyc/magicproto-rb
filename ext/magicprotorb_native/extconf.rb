# frozen_string_literal: true

require "mkmf"
require "rb_sys/mkmf"

# Builds the Rust crate and installs the artifact as
# lib/magicprotorb/magicprotorb_native.<dlext>.
create_rust_makefile("magicprotorb/magicprotorb_native")
