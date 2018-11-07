# Copyright © Mapotempo, 2013-2014
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
module PlanningsHelper
  def planning_vehicles_array(planning)
    planning.vehicle_usage_set.vehicle_usages.active.map(&:vehicle).map{ |vehicle|
      {
        id: vehicle.id,
        text: vehicle.name,
        color: vehicle.color,
        available_position: vehicle.customer.device.available_position?(vehicle) && vehicle.vehicle_usages.detect{ |item| item.vehicle_usage_set == @planning.vehicle_usage_set }.active?
      }
    }
  end

  def planning_vehicles_usages_map(planning)
    PlanningConcern.vehicles_usages_map(planning)
  end

  def planning_quantities(planning)
    planning.quantities
  end

  # It collect the enabled devices, instantiate the service then list them
  def planning_devices(customer)
    devices = {}
    device_confs = customer.device.configured_definitions || []

    device_confs.each { |_key, definition|
      service_class = "#{definition[:device].camelize}Service".constantize
      device = service_class.new(customer: customer)

      next unless device.respond_to?(:list_devices)

      begin
        list = device.list_devices
        devices[device.service_name_id] = list unless list.empty?
      rescue StandardError => e
        Rails.logger.info(e)
        raise e if ENV['RAILS_ENV'] == 'test'
      end
    }
    devices
  end

  def available_temperature?
    device_list = current_user.customer.vehicles.reject { |e|
      e.devices[:sopac_ids].nil?
    }
    !device_list.empty?
  end
end
