require 'test_helper'

class ApiWeb::V01::PlanningsControllerTest < ActionController::TestCase
  setup do
    @request.env['reseller'] = resellers(:reseller_one)
    @planning = plannings(:planning_one)
    sign_in users(:user_one)
  end

  test 'user can only view plannings from its customer' do
    ability = Ability.new(users(:user_one))
    assert ability.can? :manage, @planning
    ability = Ability.new(users(:user_three))
    assert ability.cannot? :manage, @planning

    assert @controller.can?(:edit, @planning)
    assert @controller.cannot?(:edit, plannings(:planning_three))

    get :edit, id: plannings(:planning_three)
    assert_response :redirect
  end

  test 'should sign in with api_key' do
    sign_out users(:user_one)
    get :edit, id: @planning, api_key: 'testkey1'
    assert_response :success
    assert_not_nil assigns(:planning)
  end

  test 'should get edit' do
    begin
      Stop.class_eval do
        after_initialize :after_init
        def after_init
          raise 'Stop should not be loaded'
        end
      end
      get :edit, id: @planning
      assert_response :success
      assert_valid response
    ensure
      Stop.class_eval do
        def after_init
        end
      end
    end
  end

  test 'should print' do
    get :print, id: @planning
    assert_response :success
  end
end
