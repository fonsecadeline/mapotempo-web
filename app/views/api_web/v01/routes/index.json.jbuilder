json.planning_id @planning.id

json.routes @routes do |route|
  json.route_id route.id
  json.extract! route, :color, :hidden, :locked, :outdated, :size_active, :size_destinations
  (json.duration '%i:%02i' % [(route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + (route.vehicle_usage ? route.vehicle_usage.service_time_start.to_i + route.vehicle_usage.service_time_end.to_i : 0)) / 60 / 60,
    (route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + (route.vehicle_usage ? route.vehicle_usage.service_time_start.to_i + route.vehicle_usage.service_time_end.to_i : 0)) / 60 % 60])
  json.distance number_to_human((route.distance || 0), units: :distance, precision: 3, format: '%n %u')
  json.size route.stops.size
  json.ref route.ref if @planning.customer.enable_references
  unless @planning.customer.enable_orders
    json.quantities route.quantities
  end
  if route.vehicle_usage_id
    json.vehicle_id route.vehicle_usage.vehicle.id
    json.work_or_window_time route.vehicle_usage.work_or_window_time
  end
  number = 0
  json.store_start do
    json.extract! route.vehicle_usage.default_store_start, :id, :name, :street, :postalcode, :city, :country, :lat, :lng
    (json.time route.start_time) if route.start
    (json.time_day number_of_days(route.start)) if route.start
  end if route.vehicle_usage_id && route.vehicle_usage.default_store_start
  json.stops route.stops do |stop|
    (json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_work_time || stop.no_path
    json.stop_id stop.id
    json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_work_time, :out_of_max_distance, :no_path
    json.ref stop.ref if @planning.customer.enable_references
    json.open_close1 !!stop.open1 || !!stop.close1
    json.open1 stop.open1_time
    json.close1 stop.close1_time
    json.open1_close1_days number_of_days(stop.close1)
    json.open_close2 !!stop.open2 || !!stop.close2
    json.open2 stop.open2_time
    json.close2 stop.close2_time
    json.open2_close2_days number_of_days(stop.close2)
    json.priority stop.priority
    (json.wait_time '%i:%02i' % [stop.wait_time / 60 / 60, stop.wait_time / 60 % 60]) if stop.wait_time && stop.wait_time > 60
    (json.geocoded true) if stop.position?
    (json.time stop.time_time) if stop.time
    (json.time_day number_of_days(stop.time)) if stop.time
    (json.active true) if stop.active
    (json.number number += 1) if route.vehicle_usage_id && stop.active
    json.distance (stop.distance || 0) / 1000
    if stop.is_a?(StopVisit)
      json.visits true
      visit = stop.visit
      json.visit_id visit.id
      json.destination do
        json.destination_id visit.destination.id
        (json.color visit.color) if visit.color
        (json.icon visit.icon) if visit.icon
      end
      tags = visit.destination.tags | visit.tags
      unless tags.empty?
        json.tags_present do
          json.tags do
            json.array! tags, :label
          end
        end
      end
      if @planning.customer.enable_orders
        order = stop.order
        if order
          json.orders order.products.collect(&:code).join(', ')
        end
      else
        # Hash { id, quantity, icon, label } for deliverable units
        json.quantities visit_quantities(visit, route.vehicle_usage_id && route.vehicle_usage.vehicle)
      end
    elsif stop.is_a?(StopRest)
      json.rest do
        (json.store_id route.vehicle_usage.default_store_rest.id) if route.vehicle_usage.default_store_rest
      end
    end
    json.duration l(Time.at(stop.duration).utc, format: :hour_minute_second) if stop.duration > 0
  end
  json.store_stop do
    json.extract! route.vehicle_usage.default_store_stop, :id, :name, :street, :postalcode, :city, :country, :lat, :lng
    (json.time route.end_time) if route.end
    (json.time_day number_of_days(route.end)) if route.end
    json.stop_distance (route.stop_distance || 0) / 1000
    json.stop_drive_time route.stop_drive_time
    (json.error true) if route.stop_out_of_drive_time || route.stop_out_of_work_time || route.stop_out_of_max_distance || route.stop_no_path
    json.stop_out_of_drive_time route.stop_out_of_drive_time
    json.stop_out_of_work_time route.stop_out_of_work_time
    json.stop_out_of_max_distance route.stop_out_of_max_distance
    out_of_drive_time |= route.stop_out_of_drive_time
    (json.no_path true) if route.stop_no_path
  end if route.vehicle_usage_id && route.vehicle_usage.default_store_stop
  if route.no_geolocalization || route.out_of_window || route.out_of_capacity || route.out_of_drive_time || route.out_of_work_time || route.out_of_max_distance || route.no_path
    json.route_error true
    json.route_no_geolocalization route.no_geolocalization
    json.route_out_of_window route.out_of_window
    json.route_out_of_capacity route.out_of_capacity
    json.route_out_of_drive_time route.out_of_drive_time
    json.route_out_of_work_time route.out_of_drive_time
    json.route_no_path route.no_path
  end
end
