# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("magicprotorb.gemspec")

# Builds ext/magicprotorb_native and drops the artifact in lib/magicprotorb/.
RbSys::ExtensionTask.new("magicprotorb_native", GEMSPEC) do |ext|
  ext.lib_dir = "lib/magicprotorb"
end

Rake::TestTask.new(test: :compile) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

# bundler/gem_tasks defines `install`, but it shells out to `gem install` while
# still inside the bundle. Because this gem's own gemspec is the bundle's path
# gem, that breaks the native-extension build at install time (RubyGems' build
# staging dir, ext/.../.gem.<ts>, ends up missing). Re-run the install outside
# the bundle, where `gem install` of our compiled .gem works correctly.
Rake::Task["install"].clear
desc "Build magicprotorb and install it (native extension compiled outside the bundle)"
task install: :build do
  gem_file = "pkg/#{GEMSPEC.full_name}.gem"
  Bundler.with_unbundled_env do
    sh "gem", "install", gem_file
  end
end

task default: %i[compile test]
