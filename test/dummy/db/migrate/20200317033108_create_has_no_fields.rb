class CreateHasNoFields < ActiveRecord::Migration[7.1]
  def change
    create_table :has_no_fields do |t|
      t.references :first, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
