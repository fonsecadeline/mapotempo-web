# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules"]
Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules/leaflet/dist"]
Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules/leaflet-control-geocoder"]
Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules/leaflet-draw/dist"]
Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules/bootstrap-datepicker/dist/css"]

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w( common.js )
