require 'rubygems'
require 'bundler'
Bundler.setup :default, :test

$: << File.expand_path('../../lib',__FILE__)

require 'angry_shell'
require 'exemplor'
