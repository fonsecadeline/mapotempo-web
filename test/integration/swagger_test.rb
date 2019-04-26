require 'test_helper'

class SwaggerTest < ActionDispatch::IntegrationTest

  test 'should get swagger api doc' do
    get '/api/0.1/swagger_doc'

    assert_response :success
    assert_kind_of Hash, eval(response.body)
    assert_equal 'API', eval(response.body)[:info][:title]
  end
end
