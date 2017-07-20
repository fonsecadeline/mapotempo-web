// Copyright © Mapotempo, 2013-2017
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

var ajaxWaitingGlobal = 0;
var progressDialogTimerId;

var beforeSendWaiting = function() {
  if (ajaxWaitingGlobal == 0) {
    $('body').addClass('ajax_waiting');
  }
  ajaxWaitingGlobal++;
};

var completeWaiting = function() {
  ajaxWaitingGlobal--;
  if (ajaxWaitingGlobal == 0) {
    $('body').removeClass('ajax_waiting');
  }
};

var completeAjaxMap = function() {
  completeWaiting();
};

var ajaxError = function(request, status, error) {
  var otext = request.responseText;
  var text;
  try {
    text = "";
    $.each($.parseJSON(otext), function(i, e) {
      text += " " + e;
    });
  } catch (e) {
    text = otext;
  }
  if (!text) {
    text = status;
  }
  if (request.readyState != 0) {
    stickyError(text);
  }
};

var mustache_i18n = function() {
  return function(text) {
    return I18n.t(text);
  };
};

var progressDialogFrozen = false;
var freezeProgressDialog = function(dialog) {
  if (!progressDialogFrozen) {
    dialog.find('[data-dismiss]').hide();
    dialog.off('hidden.bs.modal'); // important to avoid canceling old jobs
    dialog.off('keyup');
    beforeSendWaiting();
    progressDialogFrozen = true;
  }
};

var unfreezeProgressDialog = function(dialog, delayedJob, url, callback) {
  dialog.find('[data-dismiss]').show();
  dialog.data()['bs.modal'].options.backdrop = false;
  dialog.on('hidden.bs.modal', function() {
    // delayedJob could contain neither customer_id nor id in case of server error...
    $.ajax({
      type: 'DELETE',
      url: '/api/0.1/customers/' + delayedJob.customer_id + '/job/' + delayedJob.id + '.json',
      success: function() {
        $.ajax({
          type: 'GET',
          url: url,
          beforeSend: beforeSendWaiting,
          success: callback,
          complete: completeAjaxMap,
          error: ajaxError
        });
      },
      error: ajaxError
    });
    dialog.off('keyup');
    // Reset dialog content
    $(".dialog-progress", dialog).show();
    $(".dialog-attempts", dialog).hide();
    $(".dialog-error", dialog).hide();
    $(".dialog-no-solution", dialog).hide();
    $(".progress-bar", dialog).css("width", "0%");
  });
  dialog.on('keyup', function(e) {
    if (e.keyCode == 27) {
      dialog.modal('hide');
    }
    if (e.keyCode == 13) {
      dialog.find('.btn-primary')[0].click();
    }
  });
  completeWaiting();
  progressDialogFrozen = false;
};

var iteration = undefined;
var isProgressing = false;
var progressDialog = function(delayedJob, dialog, url, callback, options) {
  if (delayedJob !== undefined) {
    var timeout = 2000;
    var duration;
    if (delayedJob.dispatch_params_delayed_job) url += '?' + $.param(delayedJob.dispatch_params_delayed_job);

    dialog.modal(modal_options());
    freezeProgressDialog(dialog);

    var progress = delayedJob.progress && delayedJob.progress.split(';');
    $(".progress-bar", dialog).each(function(i, event) {
      // hide or show dialog-progress class
      if (typeof progress === "undefined" || progress === null || progress === '' || typeof progress[i] === "undefined" || progress[i] === '') {
        $(event).parent().parent().hide();
      } else {
        $(event).parent().parent().show();
      }

      if (!progress || typeof progress[i] === "undefined" || progress[i] === null || progress[i] === '') {
        // Inactive progress class
        $(event).parent().removeClass("active");
        $(event).css({
          transition: 'linear 0s',
          width: '0%'
        });
      } else if (progress[i] === 0 || progress[i] === '0') {
        isProgressing = true;
        $(event).parent().removeClass("active");
        $(event).css({
          transition: 'linear 0s',
          width: '0%'
        });
      } else if (progress[i] === 100 || progress[i] === '100') {
        isProgressing = true;
        $(event).parent().removeClass("active");
        $(event).css({
          transition: 'linear 0s',
          width: '100%'
        });
      } else if (progress[i] === -1 || progress[i] === '-1') {
        isProgressing = true;
        $(event).parent().addClass("active");
        $(event).css({
          transition: 'linear 0s',
          width: '100%'
        });
      } else if (progress[i].indexOf('ms') > -1) {
        // optimization in ms
        var timeSpent = progress[i].split('ms');
        if (timeSpent > 0) {
          isProgressing = true;
        }
        if (iteration != timeSpent[1] || $(".dialog-attempts-number", dialog).html() != delayedJob.attempts) {
          iteration = timeSpent[1];
          $(event).css('transition', 'linear 0s');
          $(event).css('width', '0%');

          setTimeout(function() { // to be sure width is 0%
            duration = parseInt(timeSpent[0]);
            if (duration > timeout) {
              $(event).parent().removeClass("active");
              $(event).css("transition", "linear " + ((duration - timeout - 20) / 1000) + "s");
              $(event).css("width", "100%");
            }
          }, 20);
        }
      } else if (progress[i].indexOf('/') > -1) {
        // optimization or geocoding current/total
        var currentSteps = progress[i].split('/');
        if (currentSteps[0] > 0) {
          isProgressing = true;
        }
        $(event).parent().removeClass("active");
        $(event).css("transition", "linear 0.5s");
        $(event).css("width", "" + (100 * currentSteps[0] / currentSteps[1]) + "%");
        $(event).html(progress[i]);
      } else {
        isProgressing = true;
        $(event).parent().removeClass("active");
        $(event).css("transition", "linear 2s");
        $(event).css("width", "" + progress[i] + "%");
      }
    });

    if (isProgressing) {
      $(".dialog-inqueue", dialog).hide();
    } else {
      $(".dialog-inqueue", dialog).show();
    }

    if (delayedJob.attempts > 0 && delayedJob.progress === 'no_solution') {
      options && options.error && options.error();
      isProgressing = true;
      $(".dialog-no-solution", dialog).show();
      $(".dialog-progress", dialog).hide();
      unfreezeProgressDialog(dialog, delayedJob, url, callback);

      return true;
    }

    if (delayedJob.attempts) {
      isProgressing = true;
      $(".dialog-attempts-number", dialog).html(delayedJob.attempts);
      $(".dialog-attempts", dialog).show();
    } else {
      $(".dialog-attempts", dialog).hide();
    }

    if (delayedJob.error) {
      options && options.error && options.error();
      isProgressing = true;
      $(".dialog-progress", dialog).hide();
      $(".dialog-error", dialog).show();
      unfreezeProgressDialog(dialog, delayedJob, url, callback);
    } else {
      progressDialogTimerId = setTimeout(function() {
        $.ajax({
          url: url,
          success: function(data) {
            data.dispatch_params_delayed_job = delayedJob.dispatch_params_delayed_job;
            callback(data, options);
          },
          error: ajaxError
        });
      }, 2000);

      $(document).on('page:before-change', function(e) {
        clearTimeout(progressDialogTimerId);
        $(document).off('page:before-change');
      });
    }

    return false;
  } else {
    // Called when job has ended or when delayedjob is not active
    iteration = null;
    progressDialogFrozen = false;
    if (dialog.is(':visible')) {
      dialog.modal('hide');
      $(".progress-bar", dialog).css({
        transition: 'linear 0s',
        width: '0%'
      });
      completeWaiting(); // In case of success with delayedjob unfreezeProgressDialog is never called
    }
    options && options.success && options.success();

    return true;
  }
};


var fake_select2 = function(selector, callback) {
  var fake_select2_replace = function(fake_select) {
    var select = fake_select.prev();
    fake_select.hide();
    select.show();
    callback(select);
    fake_select.off();
  };

  var fake_select2_click = function(e) {
    // On the first click on select2-look like div, initialize select2, remove the placeholder and resend the click
    var fake_select = $(this);
    e.stopPropagation();
    fake_select2_replace(fake_select);
    if (e.clientX && e.clientY) {
      $(document.elementFromPoint(e.clientX, e.clientY)).click();
    }
  };

  var fake_select2_key_event = function(e) {
    var fake_select = $(this).closest('.fake');
    e.stopPropagation();
    var parent = $(this).parent();
    fake_select2_replace(fake_select);
    var input = $('input', parent);
    input.focus();
    // var ee = jQuery.Event('keydown');
    // ee.which = e.which;
    // $('input', $(this)).trigger(ee);
  };

  selector.next()
    .on('click', fake_select2_click)
    .on('keydown', fake_select2_key_event);
};

var phoneNumberCall = function(object, userCall) {
  object.numberHref   = userCall.replace("{TEL}", object.phone_number);
  object.numberTarget = (document.location.protocol === "http:") ? '_blank' : '_self';
};
