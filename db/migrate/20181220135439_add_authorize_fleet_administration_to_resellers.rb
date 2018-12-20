class AddAuthorizeFleetAdministrationToResellers < ActiveRecord::Migration
  def change
    add_column :resellers, :authorized_fleet_administration, :boolean, default: false
  end
end
