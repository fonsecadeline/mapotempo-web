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
class V01::Layers < Grape::API
  resource :layers do
    desc 'Fetch layers.',
      detail: 'Get the list of available layers which can be used for maps.',
      nickname: 'getLayers',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Layer),
      failure: V01::Status.failures(is_array: true, override: {code_403: 'Forbidden. Operation not allowed with an admin api key.'})
    get do
      if @current_user.admin?
        error! V01::Status.code_response(:code_403, after: 'Operation not allowed with an admin api key.'), 403
      else
        present current_customer.profile.layers.load, with: V01::Entities::Layer
      end
    end
  end
end
