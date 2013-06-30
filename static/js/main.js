$(document).ready(function() {
  $('#twitter-login').oauthpopup({
    path: '/auth/twitter'
  });

  var $drop_area = $("#drop-area"),
      $drop_text = $drop_area.find('#drop-area-text'),
      animation;

  $drop_area.filedrop({
    url: '/upload',
    allowedfiletypes: ['text/html'],
    maxfilesize: 1,
    error: function(err) {
      console.log('upload error!', err);
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
    uploadFinished: function(i, file, len) {
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

  var check_complete = function() {
    if ($('.step').length == $('.step.completed').length) {
      $('#publish-submit').addClass('ready');
    } else {
      $('#publish-submit').removeClass('ready');
    }
  }

  check_complete();
});
