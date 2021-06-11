=begin
    Copyright 2020 Alex Douckas <alexdouckas@gmail.com>, Tasos Laskos <tasos.laskos@gmail.com>

    This file is part of the Engine Framework project and is subject to
    redistribution and commercial restrictions. Please see the Engine Framework
    web site for more information on licensing and terms of use.
=end

require File.expand_path(File.dirname(__FILE__)) + '/lib/cuboid'

begin
    require 'rspec'
    require 'rspec/core/rake_task'

    namespace :spec do

        desc 'Run core library tests.'
        RSpec::Core::RakeTask.new( :core ) do |t|
            t.pattern = FileList[ 'spec/cuboid/**/*_spec.rb' ]
        end

        desc 'Run plugin tests.'
        RSpec::Core::RakeTask.new( :plugins ) do |t|
            t.pattern = FileList[ 'spec/components/plugins/**/*_spec.rb' ]
        end
    end

    RSpec::Core::RakeTask.new
rescue LoadError
    puts 'If you want to run the tests please install rspec first:'
    puts '  gem install rspec'
end

desc 'Generate docs.'
task :docs do
    outdir = "../cuboid-docs"
    sh "rm -rf #{outdir}"
    sh "mkdir -p #{outdir}"

    sh "yardoc -o #{outdir}"

    sh "rm -rf .yardoc"
end

desc 'Remove reporter and log files.'
task :clean do
    files = %w(error.log *.crf *.csf *.yaml *.json *.marshal *.gem pkg/*.gem
        reports/*.crf snapshots/*.csf logs/*.log spec/support/logs/*.log
        spec/support/reports/*.crf spec/support/snapshots/*.csf
    ).map { |file| Dir.glob( file ) }.flatten

    next if files.empty?

    puts 'Removing:'
    files.each { |file| puts "  * #{file}" }
    FileUtils.rm files
end
