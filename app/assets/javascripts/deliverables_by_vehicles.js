// Copyright © Mapotempo, 2018
//
// This file is part of Mapotempo.
//
// Mapotempo is free software. You can redistribute it and/or
// modify since you respect the terms of the GNU Affero General
// Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Mapotempo is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Mapotempo. If not, see:
// <http://www.gnu.org/licenses/agpl.html>
//

'use strict';

var deliverable_by_vehicle_show = function(params) {

  var ajaxParams = {
    vehicleId: params.vehicle_id,
    planningIds: params.plannings.map(function(p) {
      return p.id;
    }).join(',')
  };

  var stateManager = (function() {

    var hasState = history.replaceState && history.pushState;
    var startUrl = ajaxParams.vehicleId + '?planning_ids=' + ajaxParams.planningIds;

    if (hasState) {
      history.replaceState(ajaxParams, "", startUrl);
    }

    return {
      pushState: function(p, cb) {

        if (!hasState) {
          return location.assign(p.URL);
        }
        history.pushState(p.state, p.title, p.URL);
        cb(p.state);
      }
    };
  })();

  var popStateHandler = function(event) {
    var state = event.state;
    if (!state.vehicleId) {
      return;
    }
    $("#vehicle_id")
      .val(event.state.vehicleId)
      .trigger('change.select2');
    requestDeliverables(state.vehicleId, state.planningIds);
  };

  window.addEventListener('popstate', popStateHandler);
  $(document).on('page:before-change', function() {
    window.removeEventListener('popstate', popStateHandler);
  });

  var templateVehicle = function(vehicle) {
    if (vehicle.id) {
      return $("<span><span class='color_small' style='background: "
        + params.vehicles[vehicle.id].color
        + "'></span>&nbsp;</span>")
        .append($("<span/>")
          .text(vehicle.text));
    }
  };

  $('#vehicle_id').on('select2:open', function() {
    $('.select2-dropdown').hide();
    $('.select2-dropdown').slideDown(200);
  });

  $('#vehicle_id').select2({
    // theme: 'bootstrap',
    templateSelection: templateVehicle,
    templateResult: templateVehicle
  }).change(function() {

    ajaxParams.vehicleId = $(this).val();

    stateManager.pushState({
      state: ajaxParams,
      title: "",
      URL: ajaxParams.vehicleId + '?planning_ids=' + ajaxParams.planningIds
    }, function(state) {
      requestDeliverables(state.vehicleId, state.planningIds);
    });
  });

  var requestDeliverables = function requestDeliverables(vehicleId, planningIds) {
    $.ajax({
      url: '/api/0.1/deliverables_by_vehicles/' + vehicleId ,
      type: 'GET',
      data: {
        planning_ids: planningIds
      },
      beforeSend: function() { $('.table-container').fadeTo(100, 0.5); },
      complete: function() { $('.table-container').fadeTo(250, 1); }
    }).done(function(data) {

      data.i18n = mustache_i18n;

      data.routes_quantities = setupQuantitiesDisplay(data);
      data.routes_total_infos = setupRoutesInfosDisplay(data);
      data.have_deliverables = data.routes_quantities.length > 0;

      $('.table-container').html(SMT['deliverables_by_vehicles/show'](data));

    }).fail(function() {
      stickyError(I18n.t('deliverables_by_vehicles.show.fail'));
    });

    var setupQuantitiesDisplay = function setupQuantitiesDisplay(data) {
      return data.routes_quantities.map(function(e) {
        e.average = e.average.toFixed(2);
        e.quantities = e.quantities.map(function(q) {
          return q !== null && q % 1 !== 0 ? q.toFixed(2) : q;
        });
        return e;
      });
    };

    var setupRoutesInfosDisplay = function setupRoutesInfosDisplay(data) {
      return {
        destinations_average: data.routes_total_infos.destinations_average,
        stops_average: data.routes_total_infos.stops_average,
        quantity_average: data.routes_total_infos.quantity_average,
        visits_duration_average: data.routes_total_infos.visits_duration_average.toHHMM(),
        drive_time_average: data.routes_total_infos.drive_time_average.toHHMM(),
        route_duration_average: data.routes_total_infos.route_duration_average.toHHMM(),
        total_per_route: data.routes_total_infos.total_per_route.map(function(e) {
          if (e.active) {
            e.total_quantity = e.total_quantity;
            e.total_drive_time = e.total_drive_time.toHHMM();
            e.total_visits_time = e.total_visits_time.toHHMM();
            e.total_route_duration = e.total_route_duration.toHHMM();
          }
          return e;
        })
      };
    };
  };
};

Paloma.controller('DeliverablesByVehicles', {
  show: function() {
    deliverable_by_vehicle_show(this.params);
  }
});
