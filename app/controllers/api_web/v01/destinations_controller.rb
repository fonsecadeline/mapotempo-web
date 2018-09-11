# Copyright © Mapotempo, 2015-2016
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
require 'value_to_boolean'

class ApiWeb::V01::DestinationsController < ApiWeb::V01::ApiWebController
  skip_before_filter :verify_authenticity_token # because rails waits for a form token with POST
  before_action :set_destination, only: [:edit_position, :update_position]
  authorize_resource

  swagger_controller :stores, 'Destinations'

  swagger_api :index do
    summary 'Display all or some destinations.'
    param :query, :ids, :array, :optional, 'Destination ids or refs (as "ref:[VALUE]") to be displayed, separated by commas', 'items' => { 'type' => 'string' }
    param :query, :store_ids, :array, :optional, 'Store ids or refs (as "ref:[VALUE]") to be displayed, separated by commas', 'items' => { 'type' => 'string' }
    param :query, :disable_clusters, 'boolean', :optional, 'Set this disable_clusters to true/1 to disable clusters on map.'
  end

  swagger_api :edit_position do
    summary 'Display a movable position marker of the destination.'
    param :path, :id, :integer, :required
  end

  swagger_api :update_position, method: :patch do
    summary 'Save the destination position.'
    param :path, :id, :integer, :required
    param :query, :lat, :float, :optional
    param :query, :lng, :float, :optional
  end

  def index
    @customer = current_user.customer
    @destinations = if params.key?(:ids)
      ids = params[:ids].split(',')
      current_user.customer.destinations.where(ParseIdsRefs.where(Destination, ids)).includes_visits
    else
      respond_to do |format|
        format.html do
          nil
        end
        format.json do
          current_user.customer.destinations.includes_visits
        end
      end
    end
    if params.key?(:store_ids)
      @stores = current_user.customer.stores.where(ParseIdsRefs.where(Store, params[:store_ids].split(',')))
    end
    @disable_clusters = ValueToBoolean.value_to_boolean(params[:disable_clusters], false)
    @method = request.method_symbol
  end

  def show
    # Not for save/update
    # => Allow using different graph
    @customer = current_user.customer
    @destination = Destination.find params[:id] || params[:destination_id]
    respond_to do |format|
      format.json
    end
  end

  def edit_position
  end

  def update_position
    respond_to do |format|
      Destination.transaction do
        if @destination.update(destination_params) && @destination.customer.save
          format.html { redirect_to api_web_v01_edit_position_destination_path(@destination), notice: t('activerecord.successful.messages.updated', model: @destination.class.model_name.human) }
        else
          format.html { render action: 'edit_position' }
        end
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_destination
    @destination = Destination.find(params[:id] || params[:destination_id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def destination_params
    params.require(:destination).permit(:lat, :lng)
  end
end
