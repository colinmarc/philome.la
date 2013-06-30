$(document).ready(function() {
  $('#twitter-login').oauthpopup({
    path: '/auth/twitter'
  });

  var $drop_area = $("#drop-area"),
      $drop_text = $drop_area.find('#drop-area-text'),
      animation;

  var check_complete = function() {
    if ($('.step').length == $('.step.completed').length) {
      $('#publish-submit').addClass('ready');
      return true;
    } else {
      $('#publish-submit').removeClass('ready');
      return false;
    }
  }

  check_complete();

  $drop_area.filedrop({
    url: '/upload',
    allowedfiletypes: ['text/html'],
    maxfilesize: 1,
    error: function(err, file) {
      var message;

      if (err == 'FileTooLarge') {
        message = "That file is too big, sorry! <a href=\"mailto:colinmarc@gmail.com?Subject=HEY%20NOW\" target=\"_blank\">Email me</a> if you're angry.";
      } else if (err == 'FileTypeNotAllowed') {
        var regex = new RegExp("\\.tws$");
        if (regex.test(file.name)) {
          message = "I can only take .html files - please build the game first from the 'Story' menu."
        } else {
          message = "Sorry, that doesn't seem to be an .html file. Email <a href=\"mailto:colinmarc@gmail.com?Subject=HEY%20NOW\" target=\"_blank\">colinmarc@gmail.com</a> if you think something went wrong.";
        }
      } else {
        message = "Oh no, something went wrong! Please shoot an email to <a href=\"mailto:colinmarc@gmail.com?Subject=HALP\" target=\"_blank\">";
      }

      $drop_text.html(message);
    },
    dragOver: function() {
      $drop_area.addClass('hover');
    },
    dragLeave: function() {
      $drop_area.removeClass('hover');
    },
    drop: function() {
      $drop_area.removeClass('hover');
    },
    uploadStarted: function(file) {
      $drop_text.html('uploading...');

      var i = 0;
      animation = setInterval(function() {
        var dots = Array((i % 3) + 2).join('.');
        $drop_text.html('uploading' + dots );
        i++;
      }, 800)
    },
    uploadFinished: function(i, file) {
      clearInterval(animation);
      var size = Math.round(file.size / 1024) + 'K', name = file.name;
      if (name.length > 25) name = name.substring(0, 22) + '...';

      $drop_text.html(name + ' (' + size + ')');

      $('#step-two').addClass('completed');
      check_complete();
    }
  });

  var $name_input = $('#publish-name');
  $name_input.on('input', function() {
    if ($name_input.val().length > 0) {
      $('#step-three').addClass('completed');
    } else {
      $('#step-three').removeClass('completed');
    }

    check_complete();
  });

  $('#publish-submit').click(function() {
    if (check_complete()) {
      $('#publish-form').submit();
    }
  });
});
