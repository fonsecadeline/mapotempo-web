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
class V01::Entities::Status400 < Grape::Entity
  def self.entity_name
    'V01_Status400'
  end

  expose(:message, documentation: { type: String, desc: 'Error messages.', values: ["Validation failed: Customers profile can't be blank, Customers router can't be blank, Customers router unauthorized in this profile, Customers max vehicles must be greater than 0"] })
  expose(:status, documentation: { type: Integer, desc: 'Error code.', values: [400] })
end
