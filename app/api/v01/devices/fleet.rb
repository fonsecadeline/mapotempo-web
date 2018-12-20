# Copyright © Mapotempo, 2016
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
class V01::Devices::Fleet < Grape::API
  namespace :devices do
    namespace :fleet do

      helpers do
        def service
          FleetService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! e.message, 200
      end

      desc 'List Devices',
        detail: 'List Mapotempo Live Devices',
        nickname: 'deviceFleetList'
      get '/devices' do
        present service.list_devices, with: V01::Entities::DeviceItem
      end

      desc 'Send Planning Routes',
        detail: 'Send Planning Routes in Mapotempo Live',
        nickname: 'deviceFleetSendMultiple'
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      post '/send_multiple' do
        device_send_routes params.slice(:type).merge(device_id: :fleet_user)
      end

      desc 'Clear Route',
        detail: 'Clear Route in Mapotempo Live',
        nickname: 'deviceFleetClear'
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
      end
      delete '/clear' do
        device_clear_route
      end

      desc 'Clear Routes',
        detail: 'Clear Routes in Mapotempo Live',
        nickname: 'deviceFleetClearMultiple'
      params do
        requires :external_refs, type: Array do
          requires :fleet_user, type: String
          requires :external_ref, type: String
        end
      end
      post '/clear_multiple' do
        routes = service.clear_routes_by_external_ref(params[:external_refs])

        routes.each { |route|
          route.clear_sent_to
          route.save!
        }

        present routes, with: V01::Entities::DeviceRouteLastSentAt
      end

      desc 'Get Fleet routes',
        detail: 'Get Fleet routes',
        nickname: 'getFleetRoutes'
      params do
        optional :from, type: Date
        optional :to, type: Date
      end
      get '/fetch_routes' do
        routes = service.fetch_routes_by_date(params[:from], params[:to], params[:sync_user])
        hash = {}

        routes.each do |route|
          route[:date] = I18n.l(Time.parse(route[:date]), format: :long)
          planning = Route.find_by(id: route[:route_id]).try(:planning)
          route[:planning_name] = planning.name unless planning.nil?

          if !hash[route[:fleet_user]].nil?
            hash[route[:fleet_user]] << route
          else
            hash[route[:fleet_user]] = [route]
          end
        end

        hash.map { |_, v|
          {
            routes_by_fleet_user: v.group_by{ |route|
              route[:fleet_user]
            }.map{ |key, val|
              { fleet_user: key, routes: val }
            }
          }
        }
      end

      desc 'Sync Vehicles',
           detail: 'Sync Vehicles',
           nickname: 'deviceFleetSync'
      post '/sync' do
        fleet_sync_vehicles @customer
        status 204
      end

      desc 'Create company with drivers',
           detail: 'Create company with a driver by vehicle',
           nickname: 'deviceFleetCreateCompanyAndDrivers'
      get '/create_company' do
        data = service.create_company['admin_user'].slice('email', 'api_key')
        data['drivers'] = service.create_or_update_drivers(@current_user)
        data
      end

      desc 'Create drivers',
           detail: 'Create driver by vehicle',
           nickname: 'deviceFleetCreateDrivers'
      get '/create_or_update_drivers' do
        service.create_or_update_drivers(@current_user) if @current_customer.reseller.authorized_fleet_administration?
      end
    end
  end
end
