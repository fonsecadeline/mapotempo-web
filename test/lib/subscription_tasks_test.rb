require 'test_helper'

class SubscriptionTasksTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'should delete only customers, his users and his vehicle_usage_sets with a subscription date expired through rake task' do
    number_of_days = rand(1..1000)
    @customer.update(end_subscription: Time.zone.today - (number_of_days + 1).days)

    assert_difference 'Customer.count', -1 do
      assert_difference 'User.count', - @customer.users.size do
        assert_difference 'VehicleUsageSet.count', - @customer.vehicle_usage_sets.size do
          Rake::Task['subscription:delete'].invoke(number_of_days)
        end
      end
    end
  end

  test 'should not delete customers with invalid parameters through rake task' do
    invalid_parameters = [0, -10, 0.1, 'A']
    invalid_parameters.each do |param|
      assert_nil Rake::Task['subscription:delete'].invoke(param)
    end
    assert_nil Rake::Task['subscription:delete'].invoke(invalid_parameters)
  end
end
