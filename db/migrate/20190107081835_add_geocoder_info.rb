class AddGeocoderInfo < ActiveRecord::Migration
  def change
    add_column :destinations, :geocoded_at, :datetime
    add_column :destinations, :geocoder_version, :string

    add_column :stores, :geocoded_at, :datetime
    add_column :stores, :geocoder_version, :string
  end
end
