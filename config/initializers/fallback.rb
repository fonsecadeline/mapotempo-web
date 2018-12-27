Mapotempo::Application.config.geocoder = Mapotempo::Application.config.geocode_geocoder unless Mapotempo::Application.config.geocoder
Mapotempo::Application.config.router = Mapotempo::Application.config.router_wrapper unless Mapotempo::Application.config.router
Mapotempo::Application.config.optimizer = Mapotempo::Application.config.optimize unless Mapotempo::Application.config.optimizer
