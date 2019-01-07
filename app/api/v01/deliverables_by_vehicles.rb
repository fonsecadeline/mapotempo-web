# Copyright © Mapotempo, 2018
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

include DeliverableByVehiclesHelper

class V01::DeliverablesByVehicles < Grape::API
  helpers do
    def deliverables_by_vehicle_params
      p = ActionController::Parameters.new(params)
      p.permit(:id, :planning_ids)
    end
  end

  resource :deliverables_by_vehicles do
    desc 'Fetch deliverables by vehicle for select plans',
      detail: 'Get list of deliverable for a vehicle on each selected plans',
      nickname: 'getDeliverablesByVehicles',
      success: V01::Entities::Layer
    params do
      requires :id, type: Integer, desc: 'Vehicle ID'
      requires :planning_ids, type: String, desc: 'Plannings ids'
    end
    get ':id' do
      p = deliverables_by_vehicle_params

      deliverable_units = current_customer.deliverable_units
      plannings = plannings_by_ids(current_customer, p[:planning_ids])

      routes = routes_by_vehicle(plannings, p[:id])
      routes_quantities = routes_quantities_by_deliverables(routes, deliverable_units)

      data = {
        plannings: plannings,
        routes_quantities: routes_quantities,
        routes_total_infos: routes_total_infos(routes_quantities, routes)
      }

      present data, with: V01::Entities::DeliverablesByVehicles
    end
  end
end
