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
class DeliverableUnitQuantity < Serializable
  def initialize(quantities)
    @hash = if quantities
      Hash[quantities.map{ |key, value|
        next unless value && !value.empty?

        if key.empty?
          raise(ActiveRecord::RecordInvalid.new(InvalidDeliverableUnitQuantity.new), I18n.t('activemodel.models.deliverable_unit.quantity.key.cannot_be_empty'))
        end

        # float value will be validated by the model
        new_value = begin
                      Float(value)
                    rescue StandardError
                      value
                    end
        [Integer(key), new_value]
      }.compact]
    else
      {}
    end
  end
end

##
class InvalidDeliverableUnitQuantity
  include ActiveModel::Model
end
