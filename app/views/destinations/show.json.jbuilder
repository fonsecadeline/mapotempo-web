json.extract! @destination, :name, :street, :detail, :postalcode, :city, :country, :lat, :lng, :comment, :phone_number, :geocoding_accuracy, :geocoding_level
json.destination_id @destination.id
json.error !@destination.position?

json.visits @destination.visits do |visit|
  json.extract! visit, :id, :tag_ids
  json.quantities visit_quantities(visit, nil) # Hash { id, quantity, icon, label } for deliverable units
  json.index_visit (@destination.visits.index(visit) + 1) if @destination.visits.size > 1
  json.ref visit.ref if @customer.enable_references
  take_over = visit.default_take_over_time_with_seconds
  json.take_over take_over
  json.duration take_over
  json.open_close1 !!visit.open1 || !!visit.close1
  json.open1 visit.open1_time
  (json.open1_day number_of_days(visit.open1)) if visit.open1
  json.close1 visit.close1_time
  (json.close1_day number_of_days(visit.close1)) if visit.close1
  json.open_close2 !!visit.open2 || !!visit.close2
  json.open2 visit.open2_time
  (json.open2_day number_of_days(visit.open2)) if visit.open2
  json.close2 visit.close2_time
  (json.close2_day number_of_days(visit.close2)) if visit.close2
  json.priority visit.priority
  tags = visit.tags | @destination.tags
  unless tags.empty?
    json.tags_present do
      json.tags do
        json.array! tags, :label
      end
    end
  end
end