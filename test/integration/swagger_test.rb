require 'test_helper'

class SwaggerTest < ActionDispatch::IntegrationTest
  include Warden::Test::Helpers

  test 'should get swagger api doc' do
    get '/api/0.1/swagger_doc'

    assert_response :success
    assert_kind_of Hash, eval(response.body)
    assert_equal 'API', eval(response.body)[:info][:title]
  end

  test 'current user should not be warden authenticated if api key is defined as param' do
    login_as User.first

    get '/api/0.1/destinations.json?api_key=nyahoo'

    assert_response :unauthorized
    assert_kind_of Hash, eval(response.body)
    assert_equal '401 Unauthorized', eval(response.body)[:error]

    Warden.test_reset!
  end
end
