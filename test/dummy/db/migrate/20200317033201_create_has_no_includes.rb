class CreateHasNoIncludes < ActiveRecord::Migration[6.0]
  def change
    create_table :has_no_includes do |t|
      t.references :first, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
