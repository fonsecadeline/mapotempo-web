// Copyright © Mapotempo, 2016-2017
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
// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
'use strict';

const deliverable_units_form = function() {
  //for turbolinks, when clicking on link_to
  $('.selectpicker').selectpicker();

  var optimisationOverloadMultiplier = function() {
    var input = $('input[name=deliverable_unit\\[optimization_overload_multiplier\\]]');
    if (!$('#deliverable_unit_optimization_overload_multiplier_yes').prop('checked')) {
      input.css('visibility', 'hidden');
      var overloadMultiplier = $('#deliverable_unit_optimization_overload_multiplier_no').prop('checked') ? 0 : -1;
      input.val(input.attr('placeholder') == overloadMultiplier ? '' : overloadMultiplier);
      input.attr('required', false);
    } else {
      input.css('visibility', 'visible');
      if (input.val() <= 0) input.val(input.attr('placeholder') > '0' ? '' : '1');
      if (input.attr('placeholder') <= 0) input.attr('required', true);
    }
  };
  optimisationOverloadMultiplier();
  $('input[name="deliverable_unit_optimization_overload_multiplier"]').change(function() {
    optimisationOverloadMultiplier();
  });

  $('[name=deliverable_unit_optimization_overload_multiplier]').change(function(e) {
    $('#deliverable_unit_optimization_overload_multiplier_no:not(:checked), #deliverable_unit_optimization_overload_multiplier_yes:not(:checked)').popover('hide');
    if (e.target.checked) {
      $(this).popover('show');
    }
  })
};

Paloma.controller('DeliverableUnits', {
  new: function() {
    deliverable_units_form();
  },
  create: function() {
    deliverable_units_form();
  },
  edit: function() {
    deliverable_units_form();
  },
  update: function() {
    deliverable_units_form();
  }
});
