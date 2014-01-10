$(document).ready(function() {
  $('#twitter-login').oauthpopup({
    path: '/auth/twitter'
  });

  var MAIL_TO = "<a href=\"mailto:colinmarc@gmail.com?Subject=HALP\" target=\"_blank\">colinmarc@gmail.com</a>"

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
        message = "That file is too big, sorry! Please mail me at " + MAIL_TO + " if you're angry.";
      } else if (err == 'FileTypeNotAllowed') {
        var regex = new RegExp("\\.tws$");
        if (regex.test(file.name)) {
          message = "I can only take .html files - please build the game first from the 'Story' menu."
        } else {
          message = "Sorry, that doesn't seem to be an .html file. Please send an email to " + MAIL_TO + "  if you think something went wrong.";
        }
      } else {
        message = "Oh no, something went wrong! Please shoot an email to " + MAIL_TO + ".";
      }

      $drop_area.removeClass('uploaded');
      $drop_text.html(message);
    },
    dragOver: function() {
      $drop_area.addClass('hover');
    },
    dragLeave: function() {
      $drop_area.removeClass('hover');
    },
    drop: function() {
      $drop_area.addClass('uploaded');
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
    uploadFinished: function(i, file, resp) {
      clearInterval(animation);

      if (!resp.valid) {
        $drop_text.html("That's an .html file, but it doesn't look like a twine game. Please send an email to " + MAIL_TO + " if you think something went wrong.");
        $drop_area.removeClass('uploaded');
        return;
      }

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
      $('#publish-name').addClass('completed');
    } else {
      $('#step-three').removeClass('completed');
      $('#publish-name').removeClass('completed');
    }

    check_complete();
  });

  var $tweet_checkbox = $('#publish-tweet-checkbox'),
      $tweet_input = $('#publish-tweet'),
      checked = true;
  $tweet_checkbox.click(function() {
    if (checked) {
      checked = false;
      $tweet_checkbox.text('☐')
      $tweet_input.val('no');
    } else {
      checked = true;
      $tweet_checkbox.text('☒')
      $tweet_input.val('yes');
    }
  });

  $('#publish-submit').click(function() {
    if (check_complete()) {
      $('#publish-form').submit();
    }
  });

  // TODO: split out profile page stuff

  $('.delete').click(function(){
    var $prompt = $(this).parent().siblings('.prompt');
    $('.prompt').not($prompt).slideUp('fast');
    $prompt.slideToggle('fast');
  });

  $('.delete-no').click(function() {
    $(this).parent().slideUp('fast');
  });

  $('.delete-yes').click(function() {
    var $this = $(this);
    $.post($this.data()['delUrl']);
    $this.parents('.game').slideUp('fast', function() {
      $this.remove();
    });
  });

  $('.game').hover(function() {
    $(this).find('.delete').removeClass('invisible');
  }, function() {
    $(this).find('.delete').addClass('invisible');
  });
});
