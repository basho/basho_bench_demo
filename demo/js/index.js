function statsSourceUrl(target, opts) {
  opts = opts || {};
  from = opts.from || "-2seconds";
  type = opts.type || "gauges"
  func = opts.func || "";

  open = "";
  close = "";
  if(func !== "") { open = "("; close = ")"; }

  return location.protocol + '//' + location.host + "/render/?from=" + from + "&format=json&noCache=true&_salt=1352477600.709&target=" + func + open + "*." + type + "." + target + close;
}

(function() {
  var description;
  description = {
    "Write Throughput": {
      source: statsSourceUrl("node_*_write_throughput", {"func": "sumSeries"}),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-one",
        title: "Write Throughput",
        unit: "req/s"
      }
    },
    "Write Latency": {
      source: statsSourceUrl("node_*_write_latency", {"func": "averageSeries"}),
      refresh_interval: 4000,
      GaugeGadget: {
        parent: "#hero-one",
        title: "LATENCY",
        to: 20
      }
    },
    "Errors": {
      source: statsSourceUrl("node_*_error_count", {"func": "sumSeries"}),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-three",
        title: "Error Count",
        value_format: "02d",
      }
    },
    "Completion": {
      source: statsSourceUrl("test_completion"),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-two",
        title: "Complete",
        value_format: "02d",
        unit: "%"
      }
    },
    "Read Throughput": {
      source: statsSourceUrl("node_*_read_throughput", {"func": "sumSeries"}),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-four",
        title: "Read Throughput",
        unit: "req/s"
      }
    },
    "Read Latency": {
      source: statsSourceUrl("node_*_read_latency", {"func": "averageSeries"}),
      refresh_interval: 4000,
      GaugeGadget: {
        parent: "#hero-four",
        title: "Latency",
        to: 20
      }
    },
    "Cluster Throughput": {
      source: statsSourceUrl("node_*_*_throughput", {"from": "-2minutes", "func": "sumSeries"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#cluster-throughput",
        title: "Cluster Throughput",
        num_labels: 0,
      },
    },
    "Cluster Latency": {
      source: statsSourceUrl("node_*_read_latency, node_*_write_latency", {"from": "-2minutes", "func": "averageSeries"}),
      refresh_interval: 2000,
      TimeSeries: {                
        parent: "#cluster-latency",            
        title: "Cluster Latency",
      },                                  
    },
    "Objects per Node": {
      source: statsSourceUrl("node_*_read_latency, node_*_write_latency", {"from": "-2minutes", "func": "averageSeries"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#objects-per-node",
        title: "Objects Per Node",
      },                 
    }, 
    "Handoffs": {
      source: statsSourceUrl("node_*_read_latency, node_*_write_latency", {"from": "-2minutes", "func": "averageSeries"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#handoffs",
        title: "Handoffs",
      },                 
    }, 

     "node_1":{source: statsSourceUrl("node_1_*_throughput", {"from": "-2minutes"}), refresh_interval: 2000, TimeSeries:{parent: "#g1-1", title: "node_1"}}, "node_3":{source: statsSourceUrl("node_3_*_throughput", {"from": "-2minutes"}), refresh_interval: 2000, TimeSeries:{parent: "#g1-2", title: "node_3"}}, "node_2":{source: statsSourceUrl("node_2_*_throughput", {"from": "-2minutes"}), refresh_interval: 2000, TimeSeries:{parent: "#g1-3", title: "node_2"}}, "node_4":{source: statsSourceUrl("node_4_*_throughput", {"from": "-2minutes"}), refresh_interval: 2000, TimeSeries:{parent: "#g2-1", title: "node_4"}},
  };


  var g = new Graphene;
  g.build(description);


}).call(this);

$(document).ready(function(){
  $('#start-button').click(function(){
    $.get('/cgi-bin/write.sh');                                                                                                                                                                                                              
    $('#start-button').attr("disabled", true);
    return false;
  });                                                                                                                                                                                                                                        
  $('#verify-button').click(function(){
    $.get('/cgi-bin/verify.sh');                                                                                                                                                                                                             
    $('#verify-button').attr("disabled", true);
    return false;
  });                                                                                                                                                                                                                                        
  $('#delete-button').click(function(){
    $.get('/cgi-bin/delete.sh');                                                                                                                                                                                                             
    $('#delete-button').attr("disabled", true);
    return false;
  });                                                                                                                                                                                                                                        
  $('#reset-button').click(function(){
    $.get('/cgi-bin/stop.sh');                                                                                                                                                                                                               
    $('#start-button').attr("disabled", false);
    $('#verify-button').attr("disabled", false);
    $('#delete-button').attr("disabled", false);
    return false;
  });
  $("#stats-button").click(function() {
    $("#stats-modal").dialog("open");
  });

  //Adjust height of overlay to fill screen when page loads
  $("#dim").css("height", $(document).height());

  //When the link that triggers the message is clicked fade in overlay/msgbox
  $(".btn-orange").click(function(){
    $("#dim").fadeIn().delay(3000).fadeOut();
    return false;
  });

  $("#tabs").tabs({
    active: 0,
    heightStyle: "auto",
  });

  $("#stats-modal").dialog({
    autoOpen: false,
    width: 1010,
    modal: true,
  });

  // Swap the modal titlebar for the tabs interface
  $("#ui-tab-dialog-close").append($("a.ui-dialog-titlebar-close"));
  $("#stats-modal").addClass("ui-tabs").prepend($("#tab_buttons"))
  $('.ui-dialog-titlebar').remove();
  $('#tabs').addClass('ui-dialog-titlebar');
  
});

//Adjust height of overlay to fill screen when browser gets resized
$(window).bind("resize", function(){
  $("#dim").css("height", $(window).height());
});
