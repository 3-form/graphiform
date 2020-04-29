class CreateSeconds < ActiveRecord::Migration[6.0]
  def change
    create_table :seconds do |t|
      t.references :first, foreign_key: true
      t.string :name
      t.float :number
      t.datetime :datetime

      t.timestamps
    end
  end
end
