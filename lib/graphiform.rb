require 'scopiform'

require 'graphiform/skeleton'

require 'graphiform/active_record_helpers'
require 'graphiform/core'
require 'graphiform/fields'

module Graphiform
  def self.included(base)
    base.class_eval do
      include Scopiform

      include Graphiform::ActiveRecordHelpers
      include Graphiform::Core
      include Graphiform::Fields
    end
  end
end
