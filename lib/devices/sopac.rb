# Copyright © Mapotempo, 2017
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

class Sopac < DeviceBase

  require 'rexml/document'
  include REXML

  def definition
    {
      device: 'sopac',
      label: 'Sopac',
      label_small: 'Sopac',
      route_operations: [],
      has_sync: false,
      help: false,
      forms: {
        settings: {
          username: :text,
          password: :password
        },
        vehicle: {
          sopac_ids: :select
        },
      }
    }
  end

  def check_auth(credentials)
    get(uname: credentials[:username], upass: credentials[:password])
  end

  def list_devices(credentials)
    doc = get(uname: credentials[:username], upass: credentials[:password])
    doc.elements['///'].map { |e|
      {
        id: e.elements['id'].text,
        text: e.elements['label'].text
      }
    }
  end

  def vehicles_temperature(customer)
    customer.vehicles.map { |v|
      if !v.devices[:sopac_ids]
        next
      end
      ids = v.devices[:sopac_ids]
      {
        vehicle_id: v.id,
        vehicle_name: v.name,
        device_infos: ids.map { |id|
          d_info = device_info(customer.devices[:sopac], id)
          {
            device_name: d_info[:label],
            device_id: id,
            temperature: d_info[:temperature],
            humidity: d_info[:humidity],
            time: d_info[:utc]
          }.compact
        }
      }
    }.compact
  end

  private

  def get(payload)
    begin
      response = RestClient.get api_url, {params: payload, content_type: :xml}
      doc = REXML::Document.new(response.body)
      if response.code == 200 && !doc.elements['message']
        doc
      elsif doc.elements['message']
        raise DeviceServiceError.new("Sopac : #{doc.elements['message'].text}")
      end
    rescue RestClient::Exception => e
      raise DeviceServiceError.new("Sopac : #{e.message}")
    end
  end

  def device_info(credentials, id)
    doc = get({ uname: credentials[:username], upass: credentials[:password], id: id})

    l = doc.elements['///label'] ? doc.elements['///label'].text : nil
    t = doc.elements['///ms/m/t'] ? doc.elements['///ms/m/t'].text : nil
    h = doc.elements['///ms/m/h'] ? doc.elements['///ms/m/h'].text : nil
    utc = doc.elements['///ms/m/utc'] ? Time.strptime(doc.elements['///ms/m/utc'].text, '%s') : nil

    {
      label: l,
      temperature: t,
      humidity: h,
      utc: utc
    }.compact
  end
end
