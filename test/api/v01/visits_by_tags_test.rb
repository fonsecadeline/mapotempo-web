require 'test_helper'

class V01::VisitsByTagsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @tag = tags(:tag_one)
    @tag.update ref: 'tag_1'
  end

  def api(tag_id_ref)
    "/api/0.1/visits_by_tags/#{tag_id_ref}?api_key=testkey1"
  end

  test 'Should return visits with tag_ref' do
    get api("ref:#{@tag.ref}")
    assert last_response.ok?, last_response.body
    assert_equal 4, JSON.parse(last_response.body).size
  end

  test 'Should return visits with tag_id' do
    get api(@tag.id)
    assert last_response.ok?, last_response.body
    assert_equal 4, JSON.parse(last_response.body).size
  end

  test 'Should return empty list with invalid tag id/ref' do
    get api(-1)
    assert last_response.ok?, last_response.body
    assert_equal 0, JSON.parse(last_response.body).size
  end

end
