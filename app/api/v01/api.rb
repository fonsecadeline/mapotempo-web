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
require 'exceptions'

class V01::Api < Grape::API
  helpers do
    def session
      env[Rack::Session::Abstract::ENV_SESSION_KEY]
    end

    def warden
      env && env['warden']
    end

    def current_customer(customer_id = nil)
      @current_user ||= params['api_key'] && User.find_by(api_key: params['api_key'])
      @current_user ||= warden.authenticated? && warden.user
      @current_customer ||= @current_user && (@current_user.admin? && customer_id ? @current_user.reseller.customers.find(customer_id) : @current_user.customer)
    end

    def authenticate!
      error!('401 Unauthorized', 401) unless env
      current_customer
      error!('401 Unauthorized', 401) unless @current_user
      error!('402 Subscription error : Subscription expired (' + @current_customer.end_subscription.to_s + ') - Contact your reseller ', 402) if @current_customer && @current_customer.end_subscription && @current_customer.end_subscription < Time.now
    end

    def authorize!
    end

    def set_time_zone
      Time.zone = @current_user.time_zone
    end

    def set_locale
      I18n.locale = env.http_accept_language.compatible_language_from(I18n.available_locales.map(&:to_s)) || I18n.default_locale
    end

    def error!(*args)
      # Workaround for close transaction on error!
      if !ActiveRecord::Base.connection.transaction_manager.current_transaction.is_a?(ActiveRecord::ConnectionAdapters::NullTransaction)
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      end
      super(*args)
    end
  end

  before do
    authenticate!
    authorize!
    set_time_zone
    set_locale
    ActiveRecord::Base.connection.begin_transaction
  end

  after do
    begin
      if @error
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      else
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.commit_transaction
      end
    rescue Exception
      ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      raise
    end
  end

  # Generate a properly formatted 404 error for all unmatched routes except '/'
  route :any, '*path' do
    error!({ error:  'Not Found',
             detail: "No such route '#{request.path}'",
             status: '404' },
           404)
  end

  # Generate a properly formatted 404 error for '/'
  route :any do
    error!({ error:  'Not Found',
             detail: "No such route '#{request.path}'",
             status: '404' },
           404)
  end

  rescue_from :all, backtrace: ENV['RAILS_ENV'] != 'production' do |e|
    ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction

    @error = e
    Rails.logger.error "\n\n#{e.class} (#{e.message}):\n    " + e.backtrace.join("\n    ") + "\n\n"
    puts Rails.backtrace_cleaner.clean(e.backtrace).join("\n    ") if ENV['RAILS_ENV'] == 'development'

    response = {message: e.message}
    if e.is_a?(ActiveRecord::RecordNotFound) || e.is_a?(ArgumentError)
      rack_response(nil, 404)
    elsif e.is_a?(ActiveRecord::RecordInvalid) || e.is_a?(RangeError) || e.is_a?(Grape::Exceptions::ValidationErrors)
      rack_response(format_message(response, e.backtrace), 400)
    elsif e.is_a?(Exceptions::OverMaxLimitError)
      rack_response(format_message(response, e.backtrace), 403)
    elsif e.is_a?(Grape::Exceptions::MethodNotAllowed)
      rack_response(format_message(response, e.backtrace), 405)
    elsif e.is_a?(Exceptions::JobInProgressError) || e.is_a?(PG::TRSerializationFailure)
      response[:message] = I18n.t('errors.database.deadlock') if e.is_a?(PG::TRSerializationFailure)
      rack_response(format_message(response, e.backtrace), 409)
    else
      rack_response(format_message(response, e.backtrace), 500)
    end
  end

  mount V01::Customers
  mount V01::DeliverableUnits
  mount V01::Destinations
  mount V01::Layers
  mount V01::Orders
  mount V01::OrderArrays
  mount V01::Plannings
  mount V01::PlanningsGet
  mount V01::Profiles
  mount V01::Routers
  mount V01::Routes
  mount V01::RoutesGet
  mount V01::Stops
  mount V01::Stores
  mount V01::Tags
  mount V01::Users
  mount V01::Vehicles
  mount V01::VehicleUsages
  mount V01::VehicleUsageSets
  mount V01::Visits
  mount V01::VisitsGet
  mount V01::Zonings

  # Devices
  mount V01::Devices::DevicesApi
  mount V01::Devices::FleetDemo
  mount V01::Devices::Fleet
  mount V01::Devices::Alyacom
  mount V01::Devices::Masternaut
  mount V01::Devices::Orange
  mount V01::Devices::Teksat
  mount V01::Devices::Tomtom
  mount V01::Devices::Trimble
  mount V01::Devices::SuiviDeFlotte
  mount V01::Devices::Notico
  mount V01::Devices::Praxedo
  mount V01::Devices::Sopac

  # Tools
  mount V01::Geocoder
end
