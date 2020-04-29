# frozen_string_literal: true

require 'active_support/concern'

module Graphiform
  module ActiveRecordHelpers
    extend ActiveSupport::Concern

    module ClassMethods
      def preferred_name(name_to_prefer = nil)
        @preferred_name ||= nil # Define to avoid instance variable not initialized warnings
        @preferred_name = name_to_prefer if name_to_prefer.present?

        @preferred_name || name
      end
    end
  end
end
