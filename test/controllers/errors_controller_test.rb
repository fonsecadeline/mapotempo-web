require 'test_helper'

class ErrorsControllerTest < ActionController::TestCase

  setup do
    @request.env['reseller'] = resellers(:reseller_one)
  end

  test 'should get error page 404 as html' do
    get :show, code: '404'
    assert_response :not_found
    assert_valid response
  end

  test 'should get error page 404 as json' do
    get :show, code: '404', format: :json
    assert_response :not_found
    assert_valid response
  end

  test 'should get error page 500 as html' do
    get :show, code: '500'
    assert_response 500
    assert_valid response
  end

  test 'should get error page 500 as json' do
    get :show, code: '500', format: :json
    assert_response 500
    assert_valid response
  end
end
