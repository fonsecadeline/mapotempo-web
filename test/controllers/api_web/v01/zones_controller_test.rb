require 'test_helper'

class ApiWeb::V01::ZonesControllerTest < ActionController::TestCase
  set_fixture_class delayed_jobs: Delayed::Backend::ActiveRecord::Job

  setup do
    @request.env['reseller'] = resellers(:reseller_one)
    @zone = zones(:zone_one)
    sign_in users(:user_one)
  end

  test 'user can only view zones from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :index, zones(:zone_one)
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :index, zones(:zone_one)
    sign_in users(:user_three)
    get :index, zoning_id: @zone.zoning_id
    assert_response :redirect
    assert_nil assigns(:zones)
  end

  test 'should get zones' do
    get :index, zoning_id: @zone.zoning_id
    assert_response :success
    assert_not_nil assigns(:zones)
    assert_valid response
  end
end
