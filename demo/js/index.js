function statsSourceUrl(target, opts) {
  opts = opts || {};
  from = opts.from || "-2seconds";
  return "http://192.168.1.100:8080/render/?from=" + from + "&format=json&noCache=true&_salt=1352477600.709&target=*.gauges." + target;
}

(function() {
  var description;
  description = {
    "Write Throughput": {
      source: statsSourceUrl("cluster_write_throughput"),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-one",
        title: "Write Throughput",
        unit: "req/s"
      }
    },
    "Write Latency": {
      source: statsSourceUrl("cluster_write_latency"),
      refresh_interval: 4000,
      GaugeGadget: {
        parent: "#hero-one",
        title: "LATENCY",
        to: 50
      }
    },
    "Read Throughput": {
      source: statsSourceUrl("cluster_read_throughput"),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-three",
        title: "Read Throughput",
	unit: "req/s"
      }
    },
    "Read Latency": {
      source: statsSourceUrl("cluster_read_latency"),
      refresh_interval: 4000,
      GaugeGadget: {
        parent: "#hero-one",
        title: "Latency",
        to: 50
      }
    },
    "Errors": {
      source: statsSourceUrl("cluster_error_count"),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-two",
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
      source: statsSourceUrl("cluster_read_throughput"),
      refresh_interval: 1000,
      GaugeLabel: {
        parent: "#hero-three",
        title: "Read Throughput",
        unit: "req/s"
      }
    },
    "Read Latency": {
      source: statsSourceUrl("cluster_read_latency"),
      refresh_interval: 4000,
      GaugeGadget: {
        parent: "#hero-three",
        title: "Latency",
        to: 50
      }
    },
    "Node 1": {
      source: statsSourceUrl("riak_1_*", {"from": "-2minutes"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#g1-1",
        title: "Node 1",
      }
    },
    "Node 2": {
      source: statsSourceUrl("riak_2_*", {"from": "-2minutes"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#g1-2",
        title: "Node 2",
      }
    },
    "Node 3": {
      source: statsSourceUrl("riak_3_*", {"from": "-2minutes"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#g1-3",
        title: "Node 3",
      }
    },
    "Node 4": {
      source: statsSourceUrl("riak_4_*", {"from": "-2minutes"}),
      refresh_interval: 2000,
      TimeSeries: {
        parent: "#g2-1",
        title: "Node 4",
      }
    },
  };


  var g = new Graphene;
  g.build(description);


}).call(this);

$('#loading').hide();

$(document).ready(function(){
  $('a#start').click(function(){
    xhr = $.ajax({
      type: "GET",
      url: "/cgi-bin/write.sh"
    });
    $('a#start').attr("disabled", true);
    return false;
  });
  $('a#verify').click(function(){
    xhr = $.ajax({
      type: "GET",
      url: "/cgi-bin/verify.sh"
    });
    $('a#verify').attr("disabled", true);
    return false;
  });
  $('a#stop').click(function(){
    xhr = $.ajax({
      type: "GET",
      url: "/cgi-bin/stop.sh"
    });
    $('a#start').attr("disabled", false);
    $('a#verify').attr("disabled", false);
    return false;
  });
});

 
