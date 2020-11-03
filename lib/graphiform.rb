require 'scopiform'

require 'graphiform/skeleton'

require 'graphiform/active_record_helpers'
require 'graphiform/core'
require 'graphiform/fields'
require 'graphiform/sort_enum'

module Graphiform
  def self.included(base)
    Graphiform.create_skeleton

    base.class_eval do
      include Scopiform

      include Graphiform::ActiveRecordHelpers
      include Graphiform::Core
      include Graphiform::Fields
    end
  end
end
