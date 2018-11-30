# Copyright © Mapotempo, 2014-2015
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
require 'coerce'

require Rails.root.join('app/api/v01/devices/device_helpers')
include Devices::Helpers

class V01::Vehicles < Grape::API

  rescue_from DeviceServiceError do |e|
    error! e.message, 200
  end

  helpers SharedParams
  helpers do
    def session
      env[Rack::Session::Abstract::ENV_SESSION_KEY]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_params
      p = ActionController::Parameters.new(params)
      p = p[:vehicle] if p.key?(:vehicle)
      p[:capacities] = Hash[p[:capacities].map { |q| [q[:deliverable_unit_id].to_s, q[:quantity]] }] if p[:capacities]

      # Deals with deprecated capacity
      unless p[:capacities]
        customer = current_customer || @current_user.admin? && @current_user.reseller.customers.where(id: params[:customer_id]).first!
        # p[:capacities] keys must be string here because of permit below
        p[:capacities] = { customer.deliverable_units[0].id.to_s => p.delete(:capacity) } if p[:capacity] && customer.deliverable_units.size > 0
        if p[:capacity1_1] || p[:capacity1_2]
          p[:capacities] = {}
          p[:capacities] = p[:capacities].merge({ customer.deliverable_units[0].id.to_s => p.delete(:capacity1_1) }) if p[:capacity1_1] && customer.deliverable_units.size > 0
          p[:capacities] = p[:capacities].merge({ customer.deliverable_units[1].id.to_s => p.delete(:capacity1_2) }) if p[:capacity1_2] && customer.deliverable_units.size > 1
        end
      end
      # Deals with deprecated speed_multiplicator
      p[:speed_multiplier] = p.delete[:speed_multiplicator] if p[:speed_multiplicator] && !p[:speed_multiplier]

      p.permit(:contact_email, :phone_number, :ref, :name, :emission, :consumption, :color, :router_id, :router_dimension, :max_distance, :speed_multiplier, router_options: [:time, :distance, :isochrone, :isodistance, :traffic, :avoid_zones, :track, :motorway, :toll, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction], capacities: (current_customer || @current_user.reseller.customers.where(id: params[:customer_id]).first!).deliverable_units.map{ |du| du.id.to_s }, devices: permit_devices)
    end

    def permit_devices
      permit = []
      Mapotempo::Application.config.devices.to_h.each{ |device_name, device_object|
        if device_object.respond_to?('definition')
          device_definition = device_object.definition
          if device_definition.key?(:forms) && device_definition[:forms].key?(:vehicle)
            device_definition[:forms][:vehicle].keys.each{ |key|
              permit << key
            }
          end
        end
      }
      permit
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_usage_params
      p = ActionController::Parameters.new(params)
      p = p[:vehicle] if p.key?(:vehicle)
      p.permit(:open, :close, :store_start_id, :store_stop_id, :store_rest_id, :rest_start, :rest_stop, :rest_duration)
    end

    ID_DESC = 'Id or the ref field value, then use "ref:[value]".'.freeze
  end

  resource :vehicles do
    desc 'Fetch customer\'s vehicles.',
      nickname: 'getVehicles',
      is_array: true,
      success: V01::Entities::Vehicle
    params do
      optional :ids, type: Array[String], desc: 'Select returned vehicles by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    get do
      vehicles = if params.key?(:ids)
        current_customer.vehicles.select{ |vehicle|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
        }
      else
        current_customer.vehicles.load
      end
      present vehicles, with: V01::Entities::Vehicle
    end

    desc 'Get vehicle\'s position.',
      detail: 'Only available if enable_vehicle_position is true for customer.',
      nickname: 'currentPosition',
      is_array: true,
      success: V01::Entities::VehiclePosition
    params do
      optional :ids, type: Array[Integer]
    end
    get 'current_position' do
      customer = current_customer
      vehicles = customer.vehicles.find params[:ids]
      positions = []
      errors = []
      begin
        Mapotempo::Application.config.devices.to_h.each{ |key, device|
          if customer.device.configured?(key)
            options = {customer: customer}
            if key == :teksat
              teksat_authenticate customer # Required to set a session variable needed for teksat Api
              options[:ticket_id] = session[:teksat_ticket_id]
            end
            service = Object.const_get(device.class.name + 'Service').new(options)
            if service.respond_to?(:get_vehicles_pos)
              if device.definition[:forms][:vehicle].try(&:length) && device.definition[:forms][:vehicle].length > 0
                (service.get_vehicles_pos || []).each do |item|
                  vehicle_id = item.delete "#{key}_vehicle_id".to_sym
                  vehicle = vehicles.detect{ |v| v.devices[device.definition[:forms][:vehicle].keys.first] == vehicle_id }
                  next unless vehicle
                  positions << item.merge(vehicle_id: vehicle.id)
                end
              else
                positions += service.get_vehicles_pos
              end
            end
          end
        }
      rescue DeviceServiceError => e
        errors << e.message
      end
      if errors.any?
        { errors: errors }
      else
        present positions, with: V01::Entities::VehiclePosition
      end
    end

    desc 'Get vehicles\'s temperature.',
      detail: 'return vehicle temperature',
      nickname: 'getTemperature',
      is_array: true,
      success: V01::Entities::VehicleTemperature
    params do
      optional :ids, type: Array[Integer]
    end
    get 'temperature' do
      customer = current_customer
      temperatures = []
      errors = []
      begin
        if customer.device.configured?(:sopac)
          device = Mapotempo::Application.config.devices[:sopac]
          service = Object.const_get(device.class.name + 'Service').new(options)
          if service.respond_to?(:vehicles_temperature)
            temperatures += service.vehicles_temperature(customer)
          end
        end
      rescue DeviceServiceError => e
        errors << e.message
      end
      if errors.any?
        { errors: errors }
      else
        present temperatures, with: V01::Entities::VehicleTemperature
      end
    end

    desc 'Fetch vehicle.',
      nickname: 'getVehicle',
      success: V01::Entities::Vehicle
    params do
      requires :id, type: String, desc: ID_DESC
    end
    get ':id' do
      id = ParseIdsRefs.read(params[:id])
      present current_customer.vehicles.where(id).first!, with: V01::Entities::Vehicle
    end

    desc 'Update vehicle.',
      nickname: 'updateVehicle',
      success: V01::Entities::Vehicle
    params do
      requires :id, type: String, desc: ID_DESC
      use :params_from_entity, entity: V01::Entities::Vehicle.documentation.except(
          :id,
          :router_options
      )

      optional :quantities, type: Array do
        requires :deliverable_unit_id, type: Integer
        requires :quantity, type: Float
      end

      optional :router_options, type: Hash do
        # optional :traffic, type: Boolean
        optional :track, type: Boolean
        optional :motorway, type: Boolean
        optional :toll, type: Boolean
        optional :trailers, type: Integer
        optional :weight, type: Float
        optional :weight_per_axle, type: Float
        optional :height, type: Float
        optional :width, type: Float
        optional :length, type: Float
        optional :hazardous_goods, type: String
        optional :max_walk_distance, type: Float
        optional :approach, type: String
        optional :snap, type: Float
        optional :strict_restriction, type: Boolean
      end
    end
    put ':id' do
      id = ParseIdsRefs.read(params[:id])
      vehicle = current_customer.vehicles.where(id).first!
      vehicle.update! vehicle_params
      present vehicle, with: V01::Entities::Vehicle
    end

    detailCreate = 'For each new created Vehicle and VehicleUsageSet a new VehicleUsage will be created at the same time (i.e. customer has 2 VehicleUsageSets \'Morning\' and \'Evening\', a new Vehicle is created: 2 new VehicleUsages will be automatically created with the new vehicle.)'
    if Mapotempo::Application.config.manage_vehicles_only_admin
      detailCreate = 'Only available with an admin api_key. ' + detailCreate
    end
    desc 'Create vehicle.',
      detail: detailCreate,
      nickname: 'createVehicle',
      success: V01::Entities::Vehicle
    params do
      if Mapotempo::Application.config.manage_vehicles_only_admin
        requires :customer_id, type: Integer
      end
      use :params_from_entity, entity: V01::Entities::Vehicle.documentation.except(
          :id,
          :router_options
      ).deep_merge(
        name: { required: true }
      ).deep_merge(V01::Entities::VehicleUsage.documentation.except(
          :id,
          :vehicle_usage_set_id,
          :open,
          :close,
          :service_time_start,
          :service_time_end,
          :work_time,
          :rest_start,
          :rest_stop,
          :rest_duration
      ).except(:vehicle_usage_set))

      optional :capacities, type: Array do
        requires :deliverable_unit_id, type: Integer
        requires :quantity, type: Float
      end

      optional :router_options, type: Hash do
        # optional :traffic, type: Boolean
        optional :track, type: Boolean
        optional :motorway, type: Boolean
        optional :toll, type: Boolean
        optional :trailers, type: Integer
        optional :weight, type: Float
        optional :weight_per_axle, type: Float
        optional :height, type: Float
        optional :width, type: Float
        optional :length, type: Float
        optional :hazardous_goods, type: String
        optional :max_walk_distance, type: Float
      end

      optional :open, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :close, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Work time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :max_distance, type: Integer, documentation: { type: 'integer', desc: 'Maximum achievable distance in meters' }
      optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
      optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    end
    post do
      if Mapotempo::Application.config.manage_vehicles_only_admin
        if @current_user.admin?
          customer = @current_user.reseller.customers.where(id: params[:customer_id]).first!
          vehicle = customer.vehicles.create(vehicle_params)
          vehicle.vehicle_usages.each { |u|
            u.assign_attributes(vehicle_usage_params)
          }
          vehicle.save!
        else
          error! 'Forbidden', 403
        end
      else
        vehicle = current_customer.vehicles.create(vehicle_params)
        vehicle.vehicle_usages.each { |u|
          u.assign_attributes(vehicle_usage_params)
        }
        vehicle.save!
      end
      present vehicle, with: V01::Entities::Vehicle
    end

    detailDelete = Mapotempo::Application.config.manage_vehicles_only_admin ? 'Only available with an admin api_key.' : nil
    desc 'Delete vehicle.',
      detail: detailDelete,
      nickname: 'deleteVehicle'
    params do
      requires :id, type: String, desc: ID_DESC
    end
    delete ':id' do
      id = ParseIdsRefs.read(params[:id])
      if Mapotempo::Application.config.manage_vehicles_only_admin
        if @current_user.admin?
          vehicle = Vehicle.for_reseller_id(@current_user.reseller.id).where(id).first!
          vehicle.destroy!
          status 204
        else
          error! 'Forbidden', 403
        end
      else
        current_customer.vehicles.where(id).first!.destroy!
        status 204
      end
    end

    desc 'Delete multiple vehicles.',
      detail: detailDelete,
      nickname: 'deleteVehicles'
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      Vehicle.transaction do
        if Mapotempo::Application.config.manage_vehicles_only_admin
          if @current_user.admin?
            Vehicle.for_reseller_id(@current_user.reseller.id).select{ |vehicle|
              params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
            }.each(&:destroy!)
            status 204
          else
            error! 'Forbidden', 403
          end
        else
          current_customer.vehicles.select{ |vehicle|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
          }.each(&:destroy!)
          status 204
        end
      end
    end
  end
end
