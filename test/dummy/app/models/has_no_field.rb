class HasNoField < ApplicationRecord
  include Graphiform

  belongs_to :first
end
