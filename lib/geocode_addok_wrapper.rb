# Copyright © Mapotempo, 2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'rest_client'

class GeocodeError < StandardError; end

class GeocodeAddokWrapper
  @@result_types = {'city' => 'city', 'street' => 'street', 'locality' => 'street', 'intersection' => 'intersection', 'house' => 'house', 'poi' => 'house'}.freeze

  def accuracy_success
    0.8
  end

  def accuracy_warning
    0.5
  end

  attr_accessor :cache, :url, :api_key

  def initialize(cache, url, api_key)
    @cache = cache
    @url = url
    @api_key = api_key
  end

  def code(street, postalcode, city, state, country)
    key = ['addok_wrapper', street, postalcode, city, state, country]
    result = @cache.read(key)
    if !result
      begin
        result = RestClient.get(@url + '/geocode.json', params: {
          api_key: @api_key,
          limit: 1,
          street: street,
          postcode: postalcode,
          city: city,
          state: state,
          country: country
        })

        @cache.write(key, result && result.body)
      rescue RestClient::Exception => e
        raise GeocodeError.new e.message
      end
    end

    data = JSON.parse(result)
    if !data['features'].empty?
      parse_geojson_feature(data['features'][0])
    end
  end

  def code_free(q, country, limit = 10, lat = nil, lng = nil)
    key = ['addok_wrapper', q]
    result = @cache.read(key)
    if !result
      begin
        result = RestClient.get(@url + '/geocode.json', params: {
          api_key: @api_key,
          limit: limit,
          query: q,
          country: country
        })

        @cache.write(key, result && result.body)
      rescue
        raise
      end
    end

    data = JSON.parse(result)
    features = data['features']
    features.collect{ |feature|
      parse_geojson_feature(feature)
    }
  end

  def reverse(lat, lng)
    begin
      result = RestClient.get(@url + '/reverse.json', params: {
        api_key: @api_key,
        lat: lat,
        lng: lng
      })
      result && result.body ? result.body : nil
    rescue RestClient::Exception => e
      raise GeocodeError.new e.message
    end
  end

  def complete(street, postalcode, city, state, country, lat = nil, lng = nil)
    begin
      result = RestClient.patch(@url + '/geocode.json', {api_key: @api_key, street: street, postalcode: postalcode, city: city, state: state, country: country, lat: lat, lng: lng}.to_json, content_type: :json, accept: :json)
    rescue RestClient::Exception => e
      raise GeocodeError.new e.message
    end
    data = JSON.parse(result)
    data['features'].collect { |address| address['properties']['geocoding'] }
  end

  def code_bulk(addresses)
    json = addresses.collect{ |address|
      {
        street: address[0],
        postcode: address[1],
        city: address[2],
        state: address[3],
        country: address[4],
      }
    }

    key = ['addok_wrapper', json]
    result = @cache.read(key)
    if !result
      begin
        result = RestClient.post(@url + '/geocode.json', {api_key: @api_key, geocodes: json}.to_json, content_type: :json, accept: :json)
        @cache.write(key, result && result.body)
      rescue RestClient::Exception => e
        raise GeocodeError.new e.message
      end
    end
    data = JSON.parse(result)
    data['geocodes'].collect{ |r|
      parse_geojson_feature(r)
    }
  end

  private

  def parse_geojson_feature(feature)
    score = feature['properties']['geocoding']['score']
    type = feature['properties']['geocoding']['type']
    label = feature['properties']['geocoding']['label']
    coordinates = feature['geometry']['coordinates'] if feature['geometry'] && feature['geometry']['coordinates']
    {lat: coordinates && coordinates[1], lng: coordinates && coordinates[0], quality: @@result_types[type], accuracy: score, free: label}
  end
end
