class CreateThirds < ActiveRecord::Migration[6.0]
  def change
    create_table :thirds do |t|
      t.references :second, foreign_key: true
      t.string :name
      t.integer :status

      t.timestamps
    end
  end
end
