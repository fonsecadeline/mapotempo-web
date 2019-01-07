require 'test_helper'

class V01::DeliverablesByVehiclesTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @vehicle = vehicles(:vehicle_one)
  end

  def api(id, param = {})
    "/api/0.1/deliverables_by_vehicles/#{id}?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI.escape(v.to_s) }.join('&')
  end

  test 'Should fetch deliverables by vehicle' do
    get api(@vehicle.id, planning_ids: @vehicle.customer.plannings.collect(&:id).join(','))
    assert last_response.ok?, last_response.body
  end

end
