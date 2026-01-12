# -*- encoding: utf-8 -*-
# stub: raktr 0.1.2 ruby lib

Gem::Specification.new do |s|
  s.name = "raktr".freeze
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tasos Laskos".freeze]
  s.date = "2025-12-24"
  s.description = "    Raktr is a simple, lightweight, pure-Ruby implementation of the Reactor\n    pattern, mainly focused on network connections -- and less so on generic tasks.\n".freeze
  s.email = "tasos.laskos@gmail.com".freeze
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "LICENSE.md".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.md".freeze, "README.md".freeze]
  s.homepage = "https://github.com/qadron/raktr".freeze
  s.licenses = ["MPL v2".freeze]
  s.rdoc_options = ["--charset=UTF-8".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A pure-Ruby implementation of the Reactor pattern.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<mutex_m>.freeze, [">= 0"])
end
