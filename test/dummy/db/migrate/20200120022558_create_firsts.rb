class CreateFirsts < ActiveRecord::Migration[7.1]
  def change
    create_table :firsts do |t|
      t.string :name
      t.date :date
      t.integer :number
      t.boolean :boolean

      t.timestamps
    end
  end
end
