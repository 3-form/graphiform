class Second < ApplicationRecord
  include Graphiform

  belongs_to :first
  has_many :thirds

  translate_this_preparers = {
    read_prepare: proc { |value| "-#{value}-" },
    write_prepare: proc { |value| value.reverse },
  }

  graphql_fields \
    :id,
    :name,
    :datetime,
    :number,
    # config
    writable: true

  graphql_field \
    :translate_this,
    # config
    type: :string,
    null: false,
    writable: true,
    **translate_this_preparers

  def translate_this
    "#{id}:#{name}"
  end
end
