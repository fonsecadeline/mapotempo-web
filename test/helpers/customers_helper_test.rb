require 'test_helper'

class CustomersHelperTest < ActionView::TestCase

  test 'display warning information if at least one vehicle have unauthorized router for profile' do
    vehicles(:vehicle_one).update_attribute(:router_id, routers(:router_osrm).id)
    assert has_vehicle_with_unauthorized_router(customers(:customer_one))
  end

  test 'do not diplay warning information if all vehicles are authorized for profile' do
    refute has_vehicle_with_unauthorized_router(customers(:customer_one))
  end

  test 'display warning information if at least one user have unauthorized layer for profile' do
    customers(:customer_one).update_attribute(:profile_id, profiles(:profile_two).id)

    assert has_user_with_unauthorized_layer(customers(:customer_one))
  end

  test 'do not display warning information on new record' do
    refute has_user_with_unauthorized_layer(Customer.new)
    refute has_vehicle_with_unauthorized_router(Customer.new)
  end
end
