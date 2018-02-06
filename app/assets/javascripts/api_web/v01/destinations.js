// Copyright © Mapotempo, 2015-2017
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

import { RoutesLayer } from '../../routes_layers'
import { mapInitialize, initializeMapHash } from '../../scaffolds';
import { destinations_edit } from '../../destinations';
import GlobalConfiguration from '../../configuration.js.erb';


export const api_web_v01_display_destinations_ = function(api, map, data) {
  var tags = {};

  var prepare_display_destination = function(destination) {
    var t = [];
    $.each(tags, function(i, tag) {
      t.push({
        id: tag.id,
        label: tag.label,
        color: tag.color ? tag.color.substr(1) : undefined,
        icon: tag.icon
      });
    });
    destination.tags = t;
    destination.i18n = mustache_i18n;
    return destination;
  };

  var addMarker = function(options) {
    var licon;
    if (options.store) {
      licon = L.divIcon({
        html: '<i class="fa ' + (options.icon || GlobalConfiguration.storeIconDefault) + ' ' + map.iconSize[options.icon_size || GlobalConfiguration.storeIconSizeDefault].name + ' store-icon" style="color: ' + (options.color || GlobalConfiguration.storeColorDefault) + ';"></i>',
        iconSize: new L.Point(map.iconSize[options.icon_size || 'large'].size, map.iconSize[options.icon_size || 'large'].size),
        iconAnchor: new L.Point(map.iconSize[options.icon_size || 'large'].size / 2, map.iconSize[options.icon_size || 'large'].size / 2),
        popupAnchor: new L.Point(0, -Math.floor(map.iconSize[options.icon_size || 'large'].size / 2.5)),
        className: 'store-icon-container'
      });
    } else {
      var pointIcon = options.icon || GlobalConfiguration.destinationIconDefault;
      var pointIconSize = options.icon_size || GlobalConfiguration.destinationIconSizeDefault;
      var pointColor = options.color || GlobalConfiguration.destinationColorDefault;
      var pointAnchor = new L.Point(map.iconSize[pointIconSize].size / 2, map.iconSize[pointIconSize].size / 2);
      var popupAnchor = [-pointAnchor.x + map.iconSize[pointIconSize].size / 2, -pointAnchor.y + map.iconSize[pointIconSize].size / 2];

      licon = L.divIcon({
        html: '<i class="fa ' + pointIcon + ' ' + map.iconSize[pointIconSize].name + ' store-icon" style="color: ' + pointColor + ';"></i>',
        iconSize: new L.Point(map.iconSize[pointIconSize].size, map.iconSize[pointIconSize].size),
        iconAnchor: pointAnchor,
        popupAnchor: popupAnchor,
        className: 'point-icon-container'
      });
    }

    return L.marker(new L.LatLng(options.lat, options.lng), {
      icon: licon
    }).addTo((options.store && api === 'destinations') ? map.storesLayers : map.markersLayers);
  };

  if (data.tags) {
    $.each(data.tags, function(i, tag) {
      tags[tag.id] = tag;
    });
  }
  ['destinations', 'stores'].forEach(function(e) {
    if (data[e]) {
      $.each(data[e], function(i, destination) {
        destination = prepare_display_destination(destination);
        if (e === 'stores') destination.store = true;
        if ($.isNumeric(destination.lat) && $.isNumeric(destination.lng)) {
          addMarker(destination).bindPopup(SMT['stops/show'](destination));
        }
      });
    }
  });
};

var api_web_v01_destinations_index = function(params, api) {
  var progressBar = Turbolinks.enableProgressBar();
  progressBar && progressBar.advanceTo(25);

  var ids = params.ids;

  var map = mapInitialize(params);
  L.control.attribution({
    prefix: false
  }).addTo(map);
  L.control.scale({
    imperial: false
  }).addTo(map);

  // var markersLayers = map.markersLayers = L.featureGroup();
  var markersLayers = map.markersLayers = new L.MarkerClusterGroup({
    showCoverageOnHover: false,
    removeOutsideVisibleBounds: true,
    disableClusteringAtZoom: (api === 'destinations' && !params.disable_clusters) ? 19 : 0
  });
  map.addLayer(markersLayers);

  var fitBounds = initializeMapHash(map, true);

  if (api === 'destinations') {
    var storesLayers = map.storesLayers = L.featureGroup();
    storesLayers.addTo(map);
  }

  var display_destinations = function(data) {
    api_web_v01_display_destinations_(api, map, data);
    if (markersLayers.getLayers().length > 0 && fitBounds) {
      map.fitBounds(markersLayers.getBounds(), {
        maxZoom: 15,
        padding: [20, 20]
      });
    }
  };

  progressBar && progressBar.advanceTo(50);
  var ajaxParams = {};
  if (ids) ajaxParams.ids = ids.join(',');
  if (params.store_ids) ajaxParams.store_ids = params.store_ids.join(',');
  $.ajax({
    url: '/api-web/0.1/' + api + '.json',
    method: params.method,
    data: ajaxParams,
    beforeSend:beforeSendWaiting,
    success: function(data) {
      if ((data.destinations && data.destinations.length) || (data.stores && data.stores.length)) {
        display_destinations(data);
      } else {
        stickyError(I18n.t('api_web.v01.destinations.index.none_destinations'));
      }
      progressBar && progressBar.done();
    },
    complete: completeWaiting,
    error: ajaxError
  });
};

Paloma.controller('ApiWeb/V01/Destinations', {
  edit_position: function() {
    destinations_edit(this.params, 'destinations');
  },
  update_position: function() {
    destinations_edit(this.params, 'destinations');
  },
  index: function() {
    api_web_v01_destinations_index(this.params, 'destinations');
  }
});

Paloma.controller('ApiWeb/V01/Stores', {
  edit_position: function() {
    destinations_edit(this.params, 'stores');
  },
  update_position: function() {
    destinations_edit(this.params, 'stores');
  },
  index: function() {
    api_web_v01_destinations_index(this.params, 'stores');
  }
});
