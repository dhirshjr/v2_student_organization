class CreateDays < ActiveRecord::Migration[5.0]
  def change
    create_table :days do |t|
      t.date :name
      t.references :cohort, foreign_key: true

      t.timestamps
    end
  end
end
