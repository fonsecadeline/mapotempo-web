# bundle exec puma -C config/puma.rb
workers 2
threads 2, 4

preload_app!

rackup DefaultRackup
port 3000
environment 'development'
