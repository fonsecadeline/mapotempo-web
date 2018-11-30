# Copyright © Mapotempo, 2013-2015
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
require 'csv'
require 'value_to_boolean'
require 'zip'

class PlanningsController < ApplicationController
  before_action :authenticate_user!
  UPDATE_ACTIONS = [:update, :move, :refresh, :switch, :automatic_insert, :update_stop, :active, :reverse_order, :apply_zonings, :optimize, :optimize_route]
  before_action :set_planning, only: [:show, :edit, :duplicate, :destroy] + UPDATE_ACTIONS
  before_action :check_no_existing_job, only: UPDATE_ACTIONS
  around_action :includes_sub_models, except: [:index, :new, :create]
  around_action :over_max_limit, only: [:create, :duplicate]

  load_and_authorize_resource

  include PlanningExport

  def index
    @plannings = current_user.customer.plannings.select{ |planning|
      !params.key?(:ids) || (params[:ids] && params[:ids].split(',').include?(planning.id.to_s))
    }
    @customer = current_user.customer
    @spreadsheet_columns = export_columns
    @params = params
    respond_to do |format|
      format.html
      format.json
      format_csv(format)
    end
  end

  def show
    @params = params
    @routes = if params[:route_ids]
      route_ids = params[:route_ids].split(',').map{ |s| Integer(s) }
      @planning.routes.select{ |r| route_ids.include?(r.id) }
    end
    respond_to do |format|
      format.html
      format.json do @with_devices = true end
      format.gpx do
        @gpx_track = !!params['track']
        response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.gpx"'
      end
      format.kml do
        response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.kml"'
        render 'plannings/show', locals: { planning: @planning }
      end
      format.kmz do
        if params[:email]
          @planning.routes.includes_vehicle_usages.joins(vehicle_usage: [:vehicle]).each do |route|
            next if !route.vehicle_usage.vehicle.contact_email
            vehicle = route.vehicle_usage.vehicle
            content = kmz_string_io(route: route, with_home_markers: true).string
            name = export_filename route.planning, route.ref || route.vehicle_usage.vehicle.name
            if Mapotempo::Application.config.delayed_job_use
              RouteMailer.delay.send_kmz_route current_user, I18n.locale, vehicle, route, name + '.kmz', content
            else
              RouteMailer.send_kmz_route(current_user, I18n.locale, vehicle, route, name + '.kmz', content).deliver_now
            end
          end
          head :no_content
        else
          send_data kmz_string_io(planning: @planning, with_home_markers: true).string,
            type: 'application/vnd.google-earth.kmz',
            filename: filename + '.kmz'
        end
      end
      format_csv(format)
    end
  end

  def new
    @planning = current_user.customer.plannings.build
    @planning.vehicle_usage_set = current_user.customer.vehicle_usage_sets[0]
  end

  def edit
    @spreadsheet_columns = export_columns
    @with_devices = true
    capabilities
  end

  def create
    respond_to do |format|
      @planning = current_user.customer.plannings.build(planning_params)
      @planning.default_routes
      if @planning.compute && @planning.save_import
        format.html { redirect_to edit_planning_path(@planning), notice: t('activerecord.successful.messages.created', model: @planning.class.model_name.human) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      if @planning.update(planning_params)
        format.html { redirect_to edit_planning_path(@planning), notice: t('activerecord.successful.messages.updated', model: @planning.class.model_name.human) }
      else
        capabilities
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @planning.destroy
    respond_to do |format|
      format.html { redirect_to plannings_url }
    end
  end

  def destroy_multiple
    Planning.transaction do
      if params['plannings']
        ids = params['plannings'].keys.collect{ |i| Integer(i) }
        current_user.customer.plannings.select{ |planning| ids.include?(planning.id) }.each(&:destroy)
      end
      respond_to do |format|
        format.html { redirect_to plannings_url }
      end
    end
  end

  def move
    respond_to do |format|
      begin
        Planning.transaction do
          route = @planning.routes.find{ |rt| rt.id == Integer(params[:route_id]) }

          if params[:stop_ids].nil?
            previous_route_id = Stop.find(params[:stop_id]).route_id
            move_stop(params[:stop_id], route, previous_route_id)
          else
            params[:stop_ids].map!(&:to_i)
            ids = @planning.routes.flat_map{ |ro|
              ro.stops.select{ |stop| params[:stop_ids].include? stop.id }
                .collect{ |stop| {stop_id: stop.id, route_id: ro.id} }
            }
            ids.each{ |id| move_stop(id[:stop_id], route, id[:route_id]) }
          end

          # save! is used to rollback all the transaction with associations
          if @planning.compute && @planning.save!
            @planning.reload
            # Send in response only modified routes
            @routes = [route]
            if params[:stop_ids].nil?
              @routes << @planning.routes.find{ |r| r.id == previous_route_id } if previous_route_id != route.id
            else
              ids.uniq{ |id|
                id[:route_id]
              }.each{ |id|
                next if id[:route_id] == route.id
                @routes << @planning.routes.find{ |r|
                  r.id == id[:route_id]
                }
              }
            end
            format.json { render action: 'show', location: @planning }
          else
            format.json { render json: @planning.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordInvalid
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def refresh
    respond_to do |format|
      @planning.compute
      if @planning.save
        @with_devices = true
        format.json { render action: 'show', location: @planning }
      else
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def switch
    respond_to do |format|
      begin
        Planning.transaction do
          route = @planning.routes.find{ |route| route.id == Integer(params[:route_id]) }
          vehicle_usage_id_was = route.vehicle_usage_id
          vehicle_usage = @planning.vehicle_usage_set.vehicle_usages.find(Integer(params[:vehicle_usage_id]))
          if route && vehicle_usage && @planning.switch(route, vehicle_usage) && @planning.save! && @planning.compute && @planning.save!
            @routes = [route]
            @routes << @planning.routes.find{ |r| r.vehicle_usage_id == vehicle_usage_id_was } if vehicle_usage_id_was != route.vehicle_usage.id
            format.json { render action: 'show', location: @planning }
          else
            format.json { render json: @planning.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordInvalid
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def automatic_insert
    respond_to do |format|
      begin
        if params[:stop_ids] && !params[:stop_ids].empty?
          stop_ids = params[:stop_ids].collect{ |id| Integer(id) }
          stops = @planning.routes.flat_map{ |r| r.stops.select{ |s| stop_ids.include? s.id } }
          route_ids = stops.collect(&:route_id).uniq
        else
          stops = @planning.routes.detect{ |r| !r.vehicle_usage_id }.stops
          route_ids = stops.any? ? [stops[0].route_id] : []
        end
        raise ActiveRecord::RecordNotFound if stops.empty?

        Planning.transaction do
          stops.each do |stop|
            route = @planning.automatic_insert(stop)
            if route
              route_ids << route.id if route_ids.exclude?(route.id)
            else
              raise Exceptions::LoopError.new
            end
          end

          if @planning.compute && @planning.save! && @planning.reload
            @routes = @planning.routes.select{ |r| route_ids.include? r.id }
            format.json { render action: :show }
          else
            format.json { render json: @planning.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordNotFound => e
        format.json { render json: { error: t('errors.planning.automatic_insert_no_result') }, status: :unprocessable_entity }
      rescue Exceptions::LoopError => e
        format.json { render json: { error: t('errors.planning.automatic_insert_no_result') }, status: :unprocessable_entity }
      rescue ActiveRecord::RecordInvalid => e
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_stop
    respond_to do |format|
      begin
        Planning.transaction do
          @route = @planning.routes.find{ |route| route.id == Integer(params[:route_id]) }
          @stop = @route.stops.find{ |stop| stop.id == Integer(params[:stop_id]) } if @route
          @stop.assign_attributes(stop_params) if @stop
          if @stop && @route.compute! && @planning.save!
            @routes = [@route]
            format.json { render action: 'show', location: @planning }
          else
            format.json { render json: @planning.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def optimize
    global = ValueToBoolean::value_to_boolean(params[:global])
    active_only = ValueToBoolean::value_to_boolean(params[:active_only])
    respond_to do |format|
      begin
        if Optimizer.optimize(@planning, nil, { global: global, synchronous: false, active_only: active_only, ignore_overload_multipliers: ignore_overload_multipliers }) && @planning.customer.save!
          format.json { render action: 'show', location: @planning }
        else
          errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
          format.json { render json: @planning.errors, status: :unprocessable_entity }
        end
      rescue NoSolutionFoundError
        @planning.errors[:base] = I18n.t('plannings.edit.dialog.optimizer.no_solution')
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      rescue ActiveRecord::RecordInvalid
        errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
        format.json { render json: errors, status: :unprocessable_entity }
      end
    end
  end

  def optimize_route
    active_only = ValueToBoolean::value_to_boolean(params[:active_only])
    optimize_overload_multiplier = ValueToBoolean::value_to_boolean(params[:optimize_overload_multiplier])
    respond_to do |format|
      route = @planning.routes.find{ |route| route.id == Integer(params[:route_id]) }
      begin
        if route && Optimizer.optimize(@planning, route, { global: false, synchronous: false, active_only: active_only, ignore_overload_multipliers: ignore_overload_multipliers }) && @planning.customer.save!
          @routes = [route]
          format.json { render action: 'show', location: @planning }
        else
          errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
          format.json { render json: errors, status: :unprocessable_entity }
        end
      rescue NoSolutionFoundError
        @planning.errors[:base] = I18n.t('plannings.edit.dialog.optimizer.no_solution')
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      rescue ActiveRecord::RecordInvalid
        errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
        format.json { render json: errors, status: :unprocessable_entity }
      end
    end
  end

  def active
    route = @planning.routes.find{ |route| route.id == Integer(params[:route_id]) }
    respond_to do |format|
      if route && route.active(params[:active].to_s.to_sym) && route.compute! && @planning.save
        @routes = [route]
        format.json { render action: 'show', location: @planning }
      else
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def duplicate
    respond_to do |format|
      @planning = @planning.duplicate
      @planning.save! validate: Mapotempo::Application.config.validate_during_duplication
      format.html { redirect_to edit_planning_path(@planning), notice: t('activerecord.successful.messages.updated', model: @planning.class.model_name.human) }
    end
  end

  def reverse_order
    route = @planning.routes.find{ |route| route.id == Integer(params[:route_id]) }
    respond_to do |format|
      if route && route.reverse_order && route.compute! && @planning.save
        @routes = [route]
        format.json { render action: 'show', location: @planning }
      else
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def apply_zonings
    respond_to do |format|
      @planning.zonings = params[:planning] && planning_params[:zoning_ids] ? current_user.customer.zonings.find(planning_params[:zoning_ids]) : []
      @planning.zoning_outdated = true
      begin
        Planning.transaction do
          @planning.split_by_zones(nil)
          @planning.compute
          if @planning.save!
            format.json { render action: :show }
          else
            format.json { render json: @planning.errors, status: :unprocessable_entity }
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        format.json { render json: @planning.errors, status: :unprocessable_entity }
      end
    end
  end

  def self.manage
    Hash[[:edit, :zoning, :export, :organize, :vehicle, :destination, :store].map{ |v| ["manage_#{v}".to_sym, true] }]
  end

  private

  def move_stop(stop_id, route, previous_route_id)
    stop_id = Integer(stop_id) unless stop_id.is_a? Integer
    stop = @planning.routes.find{ |r| r.id == previous_route_id }.stops.find { |s| s.id == stop_id }
    @planning.move_stop(route, stop, params[:index] ? Integer(params[:index]) : nil)
  end

  def ignore_overload_multipliers
    if params[:ignore_overload_multipliers]
      params[:ignore_overload_multipliers].values.map{ |obj|
        {
          unit_id: obj['unit_id'].to_i,
          ignore: ValueToBoolean.value_to_boolean(obj['ignore'])
        }
      }
    else
      []
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_planning
    @manage_planning = PlanningsController.manage
    @with_stops = ValueToBoolean.value_to_boolean(params[:with_stops], true)

    @planning = current_user.customer.plannings.find(params[:id] || params[:planning_id])
  end

  def includes_sub_models
    VehicleUsage.with_stores.scoping do
      if @with_stops
        if (params[:route_id] || params[:route_ids]) && %i[move switch].exclude?(action_name.to_sym)
          Route.where(id: [params[:route_id]] + (params[:route_ids] ? params[:route_ids].split(',') : [])).includes_destinations.scoping do
            yield
          end
        elsif %i[automatic_insert move optimize switch].include?(action_name.to_sym)
          Stop.includes_destinations.scoping do
            yield
          end
        elsif %i[show edit].exclude?(action_name.to_sym) || !request.format.html?
          Route.includes_destinations.scoping do
            yield
          end
        else
          yield
        end
      else
        yield
      end
    end
  end

  def check_no_existing_job
    raise Exceptions::JobInProgressError if Job.on_planning(@planning.customer.job_optimizer, @planning.id)
  end

  def planning_params
    p = params.require(:planning).permit(:name, :ref, :active, :date, :begin_date, :end_date, :vehicle_usage_set_id, :tag_operation, tag_ids: [], zoning_ids: [])
    p[:date] = Date.strptime(p[:date], I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK) unless p[:date].blank?
    p[:begin_date] = Date.strptime(p[:begin_date], I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK) unless p[:begin_date].blank?
    p[:end_date] = Date.strptime(p[:end_date], I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK) unless p[:end_date].blank?
    p
  end

  def stop_params
    params.require(:stop).permit(:active)
  end

  def filename
    if @planning
      format_filename(export_filename(@planning, @planning.ref))
    else
      format_filename(I18n.t('plannings.menu.plannings') + '_' + I18n.l(Time.now, format: :datepicker))
    end
  end

  def export_columns
    [
      :ref_planning,
      :planning,
      :route,
      :vehicle,
      :order,
      :stop_type,
      :active,
      :wait_time,
      :time,
      :distance,
      :drive_time,
      :out_of_window,
      :out_of_capacity,
      :out_of_drive_time,
      :out_of_work_time,
      :out_of_max_distance,
      :status,
      :eta,

      :ref,
      :name,
      :street,
      :detail,
      :postalcode,
      :city,
    ] + ((@customer || @planning.customer).with_state? ? [:state] : []) + [
      :country,
      :lat,
      :lng,
      :comment,
      :phone_number,
      :tags,

      :ref_visit,
      :duration,
      :open1,
      :close1,
      :open2,
      :close2,
      :priority,
      :tags_visit
    ] + ((@customer || @planning.customer).enable_orders ?
      [:orders] :
      (@customer || @planning.customer).deliverable_units.flat_map{ |du|
        [('quantity' + (du.label ? '[' + du.label + ']' : '')).to_sym,
        ('quantity_operation' + (du.label ? '[' + du.label + ']' : '')).to_sym]
      })
  end

  def capabilities
    @isochrone = [[@planning.vehicle_usage_set, Zoning.new.isochrone?(@planning.vehicle_usage_set, false)]]
    @isodistance = [[@planning.vehicle_usage_set, Zoning.new.isodistance?(@planning.vehicle_usage_set, false)]]
    @isoline_need_time = [[@planning.vehicle_usage_set, @planning.vehicle_usage_set.vehicle_usages.any?{ |vu| vu.vehicle.default_router_options['traffic'] }]]
  end

  def format_csv(format)
    format.excel do
      @columns = (@params[:columns] && @params[:columns].split('|')) || export_columns
      send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
      type: 'text/csv',
      filename: filename + '.csv',
      disposition: @params.key?(:disposition) ? @params[:disposition] : 'attachment'
    end
    format.csv do
      @columns = (@params[:columns] && @params[:columns].split('|')) || export_columns
      response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.csv"'
    end
  end
end
