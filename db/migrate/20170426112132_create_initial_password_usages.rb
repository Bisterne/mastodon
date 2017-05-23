class CreateInitialPasswordUsages < ActiveRecord::Migration[5.0]
  def change
    create_table :initial_password_usages do |t|
      t.integer :user_id, null: false
      t.index :user_id, unique: true
    end
  end
end
