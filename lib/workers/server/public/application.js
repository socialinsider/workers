var Application = {

  period  : 1000,
  updater : null,

  initialize : function() {
    Application.group         = $('#header').data('group');
    Application.num_processes = $('#num-processes');
    Application.num_pidfiles  = $('#num-pidfiles');
    Application.num_missing   = $('#num-missing');
    Application.num_total     = $('#num-total');
    Application.num_success   = $('#num-success');
    Application.num_ratio     = $('#num-ratio');

    Application.table_width   = $('table').width();

    Application.Workers.initialize();

    Application.Updater.start();
    Application.WebsocketClient.start();

    $('#show-fetchers-toggler input').click(function() {
      // console.log($(this).attr('checked'))
      if ( $(this).attr('checked') == 'checked' ) {
        Application.WebsocketClient.start();
      } else {
        Application.WebsocketClient.stop();
      }
    });
  },

  Change : function() {
    $.getJSON('/stats/'+Application.group, function(data) {
      // console.log(data);
      Application.num_processes.text(data.num_processes);
      Application.num_pidfiles.text(data.num_pidfiles);
      Application.num_total.text(data.total);
      Application.num_success.text(data.success);
      Application.num_ratio.attr('class', data.ratio_css_class).text(data.ratio);
      if (data.num_missing > 0) { Application.num_missing.parent().show().end().text(data.num_missing); }
      else                      { Application.num_missing.parent().hide(); }

    });
  },

  Tick : function(pid) {
    $('#pid_'+pid).
      find('td:first').
      append('<div class="tick"></div>').
      find('.tick').
      fadeIn(250).
      animate({left: '+='+(Application.table_width-30), opacity: '-=0.75'}, 1000, function() { $(this).remove(); });
  },

  Workers : {
    count : 0,
    margin: 1,
    offset: 0,

    initialize : function() {
      Application.Workers.count  = $('table tbody tr').length;
      Application.Workers.width  = Math.floor( (Application.table_width - ((Application.Workers.count-1)*Application.Workers.margin) ) / Application.Workers.count );
      $('table tbody tr').each( function(i) {
        new Application.Worker( $(this).data('pid') );
      }); 
    }
  },

  Worker : function(pid) {
    jQuery.fn.tick = function() {
        $(this).each(function() {
          $(this)
            .css('background-color', '#38BDFF')
            .delay(250)
            .animate({'background-color': '#ddd'}, 5000);
        });
        return this;
    };

    var element = $("<div></div>")
                    .attr({class: 'worker', id: 'worker_'+pid, title: 'Worker: '+pid})
                    .css({width: Application.Workers.width });
    $("#workers").append(element);
  },

  WebsocketClient : {

    start : function() {
      if ( $('#show-fetchers-toggler input').attr('checked') ) {
        var url = $('body').data('server_url');
        // console.log(url);
        Application.websocket = new WebSocket('ws://'+url+'/ws');
        Application.websocket.onmessage = function(e) { Application.WebsocketClient.handle_message(e); };
        Application.websocket.onerror = function(e) { console.error(e); };
      }
    },

    stop : function() {
      Application.websocket.close();
    },

    handle_message : function(message) {
      // console.info(message.data);
      new Application.Tick(message.data);
      $('#worker_'+message.data).tick();
    }

  },

  Updater : {

    start : function() {
      Application.updater = setInterval( function() { new Application.Change(); }, Application.period);
    },

    stop  : function() {
      clearInterval(Application.updater);
    }
  }

};

jQuery(document).ready( function() { Application.initialize(); } );
