# frozen_string_literal: true

require "test_helper"

class TestNaming < Minitest::Test
  def test_package_modules_capitalizes_each_underscore_part
    assert_equal %w[MyCo SubPkg V1], Magicprotorb::Naming.package_modules("my_co.sub_pkg.v1")
  end

  def test_package_modules_simple
    assert_equal %w[Greet], Magicprotorb::Naming.package_modules("greet")
  end

  def test_package_modules_empty
    assert_empty Magicprotorb::Naming.package_modules("")
    assert_empty Magicprotorb::Naming.package_modules(nil)
  end

  def test_constant_name_forces_first_letter_upper
    assert_equal "HelloRequest", Magicprotorb::Naming.constant_name("HelloRequest")
    assert_equal "My_Service", Magicprotorb::Naming.constant_name("My_Service")
  end
end
