$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'rspec'

require 'active_support'
require 'active_support/time'
require 'thinking_sphinx'
require 'thinking_sphinx/deltas/datetime_delta'

RSpec.configure do |config|
  #
end
