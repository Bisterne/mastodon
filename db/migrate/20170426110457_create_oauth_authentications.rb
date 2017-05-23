class CreateOauthAuthentications < ActiveRecord::Migration[5.0]
  def change
    create_table :oauth_authentications do |t|
      t.integer :user_id, null: false
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :username, null: false
      t.string :token, null: false
      t.string :token_secret, null: false
      t.timestamps

      t.index [:user_id, :provider], unique: true
      t.index [:provider, :uid], unique: true
    end
  end
end
