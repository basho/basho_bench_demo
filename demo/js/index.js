var graphConfig = {};
getGraphConfig();
var metrics = {}; 
var g = new Graphene;

function statsSourceUrl(targets, opts) {
  var opts = opts || {};
  var from = opts.from || "-2seconds";
  var type = opts.type || "gauge"
  var func = opts.func || "";

  var open = "";
  var close = "";
  if(func !== "") { open = "("; close = ")"; }

  if(type === "gauge") {
    type = "stats.gauges.";
  }
  else if(type === "counter") {
    type = "stats_counts.";
    type = "stats.";
  }

  url = location.protocol + '//' + location.host + '/render/?from=' + from + '&format=json&noCache=true';
  if($.isArray(targets)) {
    $.each(targets, function(key, target) {
      url = url + '&target=' + func + open + type + target + close;
    });
  }
  else {
    url = url + '&target=' + func + open + type + targets + close;
  }
  return url;
}

function buildGraphs(object) {

  if(!object) {
    object = graphConfig;

    $.each(object, function(index, value) {
      $.each(value, function(index2, value2) {
        if($.type(value2) == 'object') {
          if($(value2.parent).length == 0) {
            var id = 'g' + Math.floor(Math.random()*99999).toString();
            $('.sortable').append('<li id="' + id + '" class="timeseries" draggable="true" />');
            value2.parent = '#' + id;
          }
          else {
            $(value2.parent).empty();
          }
        }
      });
    });
  }

  g.build($.extend(true, true, object));
}

function removeGraph(object, item) {
  $.each(object, function(index, value) {
    $.each(value, function(index2, value2) {
      if($.type(value2) == 'object' && value2.parent == item) {
        delete object[index];
        $(item).remove();
        saveGraphConfig();
      }
    });
  });
}

//function addGraph(name, source, from, refresh_interval, type, parent) {
function addGraph(name, source, opts) {
  var opts = opts || {};
  var from = opts.from || '-2minutes';
  var type = opts.type || 'TimeSeries';
  var refresh_interval = opts.refresh_interval || 2000;
  var func = opts.func || '';
  var parent_element = opts.parent_element || '';
  var value_format = opts.value_format || '';
  var to = opts.to || '';
  var unit = opts.unit || '';

  if(parent_element === '') {
    var id = 'g' + Math.floor(Math.random()*99999).toString();
    $('.sortable').append('<li id="' + id + '" class="timeseries" draggable="true" />');
    parent_element = '#' + id;
  }

  var tempObj = new Object();

  if(func !== '') {
    tempObj[name] = {"source": statsSourceUrl(source, {"from": from, "func": func}), "refresh_interval": refresh_interval} 
    tempObj[name][type] = {"parent": parent_element, "title": name};
    graphConfig[name] = {"source": statsSourceUrl(source, {"from": from, "func": func}), "refresh_interval": refresh_interval} 
    graphConfig[name][type] = {"parent": parent_element, "title": name};
  }
  else {
    tempObj[name] = {"source": statsSourceUrl(source, {"from": from}), "refresh_interval": refresh_interval} 
    tempObj[name][type] = {"parent": parent_element, "title": name};
    graphConfig[name] = {"source": statsSourceUrl(source, {"from": from}), "refresh_interval": refresh_interval} 
    graphConfig[name][type] = {"parent": parent_element, "title": name};
  }

  if(value_format !== '') {
    tempObj[name][type]['value_format'] = value_format;
    graphConfig[name][type]['value_format'] = value_format;
  }

  if(to !== '') {
    tempObj[name][type]['to'] = to;
    graphConfig[name][type]['to'] = to;
  }

  if(unit !== '') {
    tempObj[name][type]['unit'] = unit;
    graphConfig[name][type]['unit'] = unit;
  }

  saveGraphConfig();
  buildGraphs(tempObj);
}

if(graphConfig == null) {
  addGraph("Throughput", "node_*.test.*_throughput", {"refresh_interval": 1000, "from": "-2seconds", "type": "GaugeLabel", "parent_element": "#hero-one", "unit": "req/s", "func": "sumSeries"});
  addGraph("Latency", "node_*.test.*_latency", {"refresh_interval": 4000, "from": "-2seconds", "type": "GaugeGadget", "parent_element": "#hero-one", "to": 20, "func": "averageSeries"});
  addGraph("Errors", "node_*.test.error_count", {"refresh_interval": 1000, "from": "-2seconds", "type": "GaugeLabel", "parent_element": "#hero-three", "value_format": "02d", "func": "sumSeries"});
  addGraph("Object Count", "cluster.riak.object_count", {"refresh_interval": 1000, "from": "-2seconds", "type": "GaugeLabel", "parent_element": "#hero-two", "value_format": ",02d"});
  addGraph("Completion", "cluster.test.completion", {"refresh_interval": 1000, "from": "-2seconds", "type": "GaugeGadget", "parent_element": "#hero-two"});

  addGraph('node_1', 'node_1.test.*_throughput');
  addGraph('node_3', 'node_3.test.*_throughput');
  addGraph('node_2', 'node_2.test.*_throughput');
  addGraph('node_4', 'node_4.test.*_throughput');
}

function saveGraphConfig() {
  $.cookie("graphConfig", JSON.stringify(graphConfig));
}

function getGraphConfig() {
  var config = JSON.parse($.cookie("graphConfig"));
  if(config == null) {
    graphConfig = {};
  }
  else {
    graphConfig = config;
  }
}


$(document).ready(function(){
  $('#start-button').click(function(){
    $.get('/cgi-bin/write.sh');                                                                                                                                                                                                              
    $(this).attr("disabled", "disabled");
    return false;
  });                                                                                                                                                                                                                                        

  $('#verify-button').click(function(){
    $.get('/cgi-bin/verify.sh');                                                                                                                                                                                                             
    $(this).attr("disabled", "disabled");
    return false;
  });                                                                                                                                                                                                                                        

  $('#delete-button').click(function(){
    $.get('/cgi-bin/delete.sh');                                                                                                                                                                                                             
    $(this).attr("disabled", "disabled");
    return false;
  });                                                                                                                                                                                                                                        

  $('#reset-button').click(function(){
    $.get('/cgi-bin/stop.sh');                                                                                                                                                                                                               
    $('#start-button').removeAttr("disabled");
    $('#verify-button').removeAttr("disabled");
    $('#delete-button').removeAttr("disabled");
    return false;
  });

  // Fade in the spinner on control button click 
  $(".btn-orange").click(function(){
    $('#dim').fadeIn().delay(3000).fadeOut();
    return false;
  });

  $('#add-graph-button').click(function() {
    if(!graphConfig[$('#graph_title').val()] && $('#select_attribute').val() != null) {
      from = $('#graph_time').val() || '2';
      addGraph($('#graph_title').val(), $('#select_attribute').val(), {"from": '-' + from + 'minutes'});    
    }

    $('#graph_title').val(null);
    $('#select_attribute').val('').trigger('liszt:updated');
    $('#graph_time').val(null);
  });

  $('.timeseries').live('mouseenter', function() {
    $(this).append('<button type="button" class="close">&times;</button>')
    $('.close').click(function() {
      removeGraph(graphConfig, '#' + $(this).parent().attr('id'));
    });
  });

  $('.timeseries').live('mouseleave', function() {
    $('.close').remove();
  });

  $('.sortable').sortable();
  $('html').disableSelection();

  // Populate metrics object
  $.getJSON('/metrics/index.json', function(data) { 
    $.each(data, function(key, val) { 
      if(val.match(/^stats.gauges/)) { 
        stat = val.split('.');
        if(metrics[stat[2]]) {
          if(metrics[stat[2]][stat[3]]) { 
            metrics[stat[2]][stat[3]].push(stat[4]); 
          } 
          else {
            metrics[stat[2]][stat[3]] = [];
            metrics[stat[2]][stat[3]].push(stat[4]);
          }  
        }
        else {
          metrics[stat[2]] = {};
          metrics[stat[2]][stat[3]] = [];
          metrics[stat[2]][stat[3]].push(stat[4]);
        }
      } 
    }); 

    $.each(metrics, function(node) {
      var optGroup = $('<optgroup label="' + node + '" />');
      if(metrics[node]['riak']) {
        $.each(metrics[node]['riak'], function(key, metric) {
         optGroup.append(new Option(node + '.' + 'riak' + '.' + metric)); 
        });
      }
      if(metrics[node]['riak']) {
        $.each(metrics[node]['test'], function(key, metric) {
         optGroup.append(new Option(node + '.' + 'test' + '.' + metric)); 
        });
      }
      $('#select_attribute').append(optGroup);
    });
    $('#select_attribute').chosen();
  });
  
  buildGraphs();
});

// Adjust graph sizes on window resize
$(window).bind('resize', function(){
  buildGraphs();
});
