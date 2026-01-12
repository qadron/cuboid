# -*- encoding: utf-8 -*-
# stub: toq 0.1.3 ruby lib

Gem::Specification.new do |s|
  s.name = "toq".freeze
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tasos Laskos".freeze]
  s.date = "2026-01-04"
  s.description = "        Toq is a simple and lightweight Remote Procedure Call protocol\n        used to provide the basis for Arachni's distributed infrastructure.\n".freeze
  s.email = "tasos.laskos@gmail.com".freeze
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "LICENSE.md".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.md".freeze, "README.md".freeze]
  s.homepage = "https://github.com/qadron/toq".freeze
  s.licenses = ["MPL v2".freeze]
  s.rdoc_options = ["--charset=UTF-8".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Simple RPC protocol.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<logger>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<raktr>.freeze, [">= 0"])
end
