class CreateIdentityProviders < ActiveRecord::Migration[6.1]
  def change
    create_table :identity_providers do |t|
      t.string :name
      t.text :sp_meta
      t.string :idp_okta_id

      t.timestamps
    end
  end
end
