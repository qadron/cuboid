# -*- encoding: utf-8 -*-
# stub: concurrent-ruby-ext 1.3.6 ruby lib
# stub: ext/concurrent-ruby-ext/extconf.rb

Gem::Specification.new do |s|
  s.name = "concurrent-ruby-ext".freeze
  s.version = "1.3.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jerry D'Antonio".freeze, "The Ruby Concurrency Team".freeze]
  s.date = "2025-12-13"
  s.description = "    C extensions to optimize the concurrent-ruby gem when running under MRI.\n    Please see http://concurrent-ruby.com for more information.\n".freeze
  s.email = "concurrent-ruby@googlegroups.com".freeze
  s.extensions = ["ext/concurrent-ruby-ext/extconf.rb".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "LICENSE.txt".freeze, "CHANGELOG.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.txt".freeze, "README.md".freeze, "ext/concurrent-ruby-ext/extconf.rb".freeze]
  s.homepage = "http://www.concurrent-ruby.com".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "C extensions to optimize concurrent-ruby under MRI.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["= 1.3.6"])
end
