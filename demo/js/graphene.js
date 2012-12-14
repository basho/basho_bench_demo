(function() {
  var Graphene,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Graphene = (function() {

    function Graphene() {
      this.build = __bind(this.build, this);
    }

    Graphene.prototype.demo = function() {
      return this.is_demo = true;
    };

    Graphene.prototype.build = function(json) {
      var _this = this;
      return _.each(_.keys(json), function(k) {
        var klass, model_opts, ts;
        console.log("building [" + k + "]");
        if (_this.is_demo) {
          klass = Graphene.DemoTimeSeries;
        } else {
          klass = Graphene.TimeSeries;
        }
        model_opts = {
          source: json[k].source
        };
        delete json[k].source;
        if (json[k].refresh_interval) {
          model_opts.refresh_interval = json[k].refresh_interval;
          delete json[k].refresh_interval;
        }
        ts = new klass(model_opts);
        return _.each(json[k], function(opts, view) {
          klass = eval("Graphene." + view + "View");
          console.log(_.extend({
            model: ts
          }, opts));
          new klass(_.extend({
            model: ts
          }, opts));
          return ts.start();
        });
      });
    };

    Graphene.prototype.discover = function(url, dash, parent_specifier, cb) {
      return $.get("" + url + "/dashboard/load/" + dash, function(data) {
        var desc, i;
        i = 0;
        desc = {};
        _.each(data['state']['graphs'], function(graph) {
          var path;
          path = graph[2];
          desc["Graph " + i] = {
            source: "" + url + path + "&format=json",
            TimeSeries: {
              parent: parent_specifier(i, url)
            }
          };
          return i++;
        });
        return cb(desc);
      });
    };

    return Graphene;

  })();

  this.Graphene = Graphene;

  Graphene.GraphiteModel = (function(_super) {

    __extends(GraphiteModel, _super);

    function GraphiteModel() {
      this.process_data = __bind(this.process_data, this);
      this.refresh = __bind(this.refresh, this);
      this.stop = __bind(this.stop, this);
      this.start = __bind(this.start, this);
      GraphiteModel.__super__.constructor.apply(this, arguments);
    }

    GraphiteModel.prototype.defaults = {
      source: '',
      data: null,
      ymin: 0,
      ymax: 0,
      refresh_interval: 1000
    };

    GraphiteModel.prototype.debug = function() {
      return console.log("" + (this.get('refresh_interval')));
    };

    GraphiteModel.prototype.start = function() {
      this.refresh();
      console.log("Starting to poll at " + (this.get('refresh_interval')));
      return this.t_index = setInterval(this.refresh, this.get('refresh_interval'));
    };

    GraphiteModel.prototype.stop = function() {
      return clearInterval(this.t_index);
    };

    GraphiteModel.prototype.refresh = function() {
      var options, url,
        _this = this;
      url = this.get('source');
      if (-1 === url.indexOf('&jsonp=?')) url = url + '&jsonp=?';
      options = {
        url: url,
        dataType: 'json',
        jsonp: 'jsonp',
        success: function(js) {
          console.log("got data.");
          return _this.process_data(js);
        }
      };
      return $.ajax(options);
    };

    GraphiteModel.prototype.process_data = function() {
      return null;
    };

    return GraphiteModel;

  })(Backbone.Model);

  Graphene.DemoTimeSeries = (function(_super) {

    __extends(DemoTimeSeries, _super);

    function DemoTimeSeries() {
      this.add_points = __bind(this.add_points, this);
      this.refresh = __bind(this.refresh, this);
      this.stop = __bind(this.stop, this);
      this.start = __bind(this.start, this);
      DemoTimeSeries.__super__.constructor.apply(this, arguments);
    }

    DemoTimeSeries.prototype.defaults = {
      range: [0, 1000],
      num_points: 100,
      num_new_points: 1,
      num_series: 2,
      refresh_interval: 3000
    };

    DemoTimeSeries.prototype.debug = function() {
      return console.log("" + (this.get('refresh_interval')));
    };

    DemoTimeSeries.prototype.start = function() {
      var _this = this;
      console.log("Starting to poll at " + (this.get('refresh_interval')));
      this.data = [];
      _.each(_.range(this.get('num_series')), function(i) {
        return _this.data.push({
          label: "Series " + i,
          ymin: 0,
          ymax: 0,
          points: []
        });
      });
      this.point_interval = this.get('refresh_interval') / this.get('num_new_points');
      _.each(this.data, function(d) {
        return _this.add_points(new Date(), _this.get('range'), _this.get('num_points'), _this.point_interval, d);
      });
      this.set({
        data: this.data
      });
      return this.t_index = setInterval(this.refresh, this.get('refresh_interval'));
    };

    DemoTimeSeries.prototype.stop = function() {
      return clearInterval(this.t_index);
    };

    DemoTimeSeries.prototype.refresh = function() {
      var last, num_new_points, start_date,
        _this = this;
      this.data = _.map(this.data, function(d) {
        d = _.clone(d);
        d.points = _.map(d.points, function(p) {
          return [p[0], p[1]];
        });
        return d;
      });
      last = this.data[0].points.pop();
      this.data[0].points.push(last);
      start_date = last[1];
      num_new_points = this.get('num_new_points');
      _.each(this.data, function(d) {
        return _this.add_points(start_date, _this.get('range'), num_new_points, _this.point_interval, d);
      });
      return this.set({
        data: this.data
      });
    };

    DemoTimeSeries.prototype.add_points = function(start_date, range, num_new_points, point_interval, d) {
      var _this = this;
      _.each(_.range(num_new_points), function(i) {
        var new_point;
        new_point = [range[0] + Math.random() * (range[1] - range[0]), new Date(start_date.getTime() + (i + 1) * point_interval)];
        d.points.push(new_point);
        if (d.points.length > _this.get('num_points')) return d.points.shift();
      });
      d.ymin = d3.min(d.points, function(d) {
        return d[0];
      });
      return d.ymax = d3.max(d.points, function(d) {
        return d[0];
      });
    };

    return DemoTimeSeries;

  })(Backbone.Model);

  Graphene.BarChart = (function(_super) {

    __extends(BarChart, _super);

    function BarChart() {
      this.process_data = __bind(this.process_data, this);
      BarChart.__super__.constructor.apply(this, arguments);
    }

    BarChart.prototype.process_data = function(js) {
      var data;
      console.log('process data barchart');
      data = _.map(js, function(dp) {
        var max, min;
        min = d3.min(dp.datapoints, function(d) {
          return d[0];
        });
        if (min === void 0) return null;
        max = d3.max(dp.datapoints, function(d) {
          return d[0];
        });
        if (max === void 0) return null;
        _.each(dp.datapoints, function(d) {
          return d[1] = new Date(d[1] * 1000);
        });
        return {
          points: _.reject(dp.datapoints, function(d) {
            return d[0] === null;
          }),
          ymin: min,
          ymax: max,
          label: dp.target
        };
      });
      data = _.reject(data, function(d) {
        return d === null;
      });
      return this.set({
        data: data
      });
    };

    return BarChart;

  })(Graphene.GraphiteModel);

  Graphene.TimeSeries = (function(_super) {

    __extends(TimeSeries, _super);

    function TimeSeries() {
      this.process_data = __bind(this.process_data, this);
      TimeSeries.__super__.constructor.apply(this, arguments);
    }

    TimeSeries.prototype.process_data = function(js) {
      var data;
      data = _.map(js, function(dp) {
        var max, min;
        min = d3.min(dp.datapoints, function(d) {
          return d[0];
        });
        if (min === void 0) return null;
        max = d3.max(dp.datapoints, function(d) {
          return d[0];
        });
        if (max === void 0) return null;
        _.each(dp.datapoints, function(d) {
          return d[1] = new Date(d[1] * 1000);
        });
        return {
          points: _.reject(dp.datapoints, function(d) {
            return d[0] === null;
          }),
          ymin: min,
          ymax: max,
          label: dp.target
        };
      });
      data = _.reject(data, function(d) {
        return d === null;
      });
      return this.set({
        data: data
      });
    };

    return TimeSeries;

  })(Graphene.GraphiteModel);

  Graphene.GaugeGadgetView = (function(_super) {

    __extends(GaugeGadgetView, _super);

    function GaugeGadgetView() {
      this.render = __bind(this.render, this);
      this.by_type = __bind(this.by_type, this);
      GaugeGadgetView.__super__.constructor.apply(this, arguments);
    }

    GaugeGadgetView.prototype.className = 'gauge-gadget-view';

    GaugeGadgetView.prototype.tagName = 'div';

    GaugeGadgetView.prototype.initialize = function() {
      var config;
      this.title = this.options.title;
      this.type = this.options.type;
      this.parent = this.options.parent || '#parent';
      this.value_format = this.options.value_format || ".3s";
      this.value_format = d3.format(this.value_format);
      this.null_value = 0;
      this.from = this.options.from || 0;
      this.to = this.options.to || 100;
      this.vis = d3.select(this.parent).append("div").attr("class", "ggview").attr("id", this.title + "GaugeContainer");
      config = {
        size: this.options.size || 120,
        label: this.title,
        minorTicks: 5,
        min: this.from,
        max: this.to
      };
      config.redZones = [];
      config.redZones.push({
        from: this.options.red_from || 0.9 * this.to,
        to: this.options.red_to || this.to
      });
      config.yellowZones = [];
      config.yellowZones.push({
        from: this.options.yellow_from || 0.75 * this.to,
        to: this.options.yellow_to || 0.9 * this.to
      });
      this.gauge = new Gauge("" + this.title + "GaugeContainer", config);
      this.gauge.render();
      this.model.bind('change', this.render);
      return console.log("GG view ");
    };

    GaugeGadgetView.prototype.by_type = function(d) {
      switch (this.type) {
        case "min":
          return d.ymin;
        case "max":
          return d.ymax;
        case "current":
          return d.points[d.points.length][0];
        default:
          return d.points[0][0];
      }
    };

    GaugeGadgetView.prototype.render = function() {
      var data, datum;
      console.log("rendering.");
      data = this.model.get('data');
      datum = data && data.length > 0 ? data[0] : {
        ymax: this.null_value,
        ymin: this.null_value,
        points: [[this.null_value, 0]]
      };
      return this.gauge.redraw(this.by_type(datum));
    };

    return GaugeGadgetView;

  })(Backbone.View);

  Graphene.GaugeLabelView = (function(_super) {

    __extends(GaugeLabelView, _super);

    function GaugeLabelView() {
      this.render = __bind(this.render, this);
      this.by_type = __bind(this.by_type, this);
      GaugeLabelView.__super__.constructor.apply(this, arguments);
    }

    GaugeLabelView.prototype.className = 'gauge-label-view';

    GaugeLabelView.prototype.tagName = 'div';

    GaugeLabelView.prototype.initialize = function() {
      this.unit = this.options.unit;
      this.title = this.options.title;
      this.type = this.options.type;
      this.parent = this.options.parent || '#parent';
      this.value_format = this.options.value_format || ".3s";
      this.value_format = d3.format(this.value_format);
      this.null_value = 0;
      this.vis = d3.select(this.parent).append("div").attr("class", "glview");
      if (this.title) {
        this.vis.append("div").attr("class", "label").text(this.title);
      }
      this.model.bind('change', this.render);
      return console.log("GL view ");
    };

    GaugeLabelView.prototype.by_type = function(d) {
      switch (this.type) {
        case "min":
          return d.ymin;
        case "max":
          return d.ymax;
        case "current":
          return d.points[d.points.length][0];
        default:
          return d.points[0][0];
      }
    };

    GaugeLabelView.prototype.render = function() {
      var data, datum, metric, metric_items, vis,
        _this = this;
      data = this.model.get('data');
      console.log(data);
      datum = data && data.length > 0 ? data[0] : {
        ymax: this.null_value,
        ymin: this.null_value,
        points: [[this.null_value, 0]]
      };
      vis = this.vis;
      metric_items = vis.selectAll('div.metric').data([datum], function(d) {
        return _this.by_type(d);
      });
      metric_items.exit().remove();
      metric = metric_items.enter().insert('div', ":first-child").attr('class', "metric" + (this.type ? ' ' + this.type : ''));
      metric.append('span').attr('class', 'value').text(function(d) {
        return _this.value_format(_this.by_type(d));
      });
      if (this.unit) {
        return metric.append('span').attr('class', 'unit').text(this.unit);
      }
    };

    return GaugeLabelView;

  })(Backbone.View);

  Graphene.TimeSeriesView = (function(_super) {

    __extends(TimeSeriesView, _super);

    function TimeSeriesView() {
      this.render = __bind(this.render, this);
      TimeSeriesView.__super__.constructor.apply(this, arguments);
    }

    TimeSeriesView.prototype.tagName = 'div';

    TimeSeriesView.prototype.initialize = function() {
      this.line_height = this.options.line_height || 16;
      this.animate_ms = this.options.animate_ms || 500;
      this.num_labels = this.options.num_labels || 3;
      this.sort_labels = this.options.labels_sort || 'desc';
      this.display_verticals = this.options.display_verticals || false;
      this.width = this.options.width || 400;
      this.height = this.options.height || 100;
      this.padding = this.options.padding || [this.line_height * 2, 32, this.line_height * (3 + this.num_labels), 32];
      this.title = this.options.title;
      this.label_formatter = this.options.label_formatter || function(label) {
        return label;
      };
      this.firstrun = true;
      this.parent = this.options.parent || '#parent';
      this.null_value = 0;
      this.vis = d3.select(this.parent).append("svg").attr("class", "tsview").attr("width", this.width + (this.padding[1] + this.padding[3])).attr("height", this.height + (this.padding[0] + this.padding[2])).append("g").attr("transform", "translate(" + this.padding[3] + "," + this.padding[0] + ")");
      this.value_format = this.options.value_format || ".3s";
      this.value_format = d3.format(this.value_format);
      this.model.bind('change', this.render);
      return console.log("TS view: " + this.width + "x" + this.height + " padding:" + this.padding + " animate: " + this.animate_ms + " labels: " + this.num_labels);
    };

    TimeSeriesView.prototype.render = function() {
      var area, d, data, dmax, dmin, leg_items, line, litem_enters, litem_enters_text, order, points, title, vis, x, xAxis, xmax, xmin, xpoints, xtick_sz, y, yAxis,
        _this = this;
      console.log("rendering.");
      data = this.model.get('data');
      data = data && data.length > 0 ? data : [
        {
          ymax: this.null_value,
          ymin: this.null_value,
          points: [[this.null_value, 0], [this.null_value, 0]]
        }
      ];
      dmax = _.max(data, function(d) {
        return d.ymax;
      });
      dmin = _.min(data, function(d) {
        return d.ymin;
      });
      xpoints = _.flatten((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = data.length; _i < _len; _i++) {
          d = data[_i];
          _results.push(d.points.map(function(p) {
            return p[1];
          }));
        }
        return _results;
      })());
      xmin = _.min(xpoints, function(x) {
        return x.valueOf();
      });
      xmax = _.max(xpoints, function(x) {
        return x.valueOf();
      });
      x = d3.time.scale().domain([xmin, xmax]).range([0, this.width]);
      y = d3.scale.linear().domain([dmin.ymin, dmax.ymax]).range([this.height, 0]).nice();
      xtick_sz = this.display_verticals ? -this.height : 0;
      xAxis = d3.svg.axis().scale(x).ticks(4).tickSize(xtick_sz).tickSubdivide(true);
      yAxis = d3.svg.axis().scale(y).ticks(4).tickSize(-this.width).orient("left").tickFormat(d3.format("s"));
      vis = this.vis;
      line = d3.svg.line().x(function(d) {
        return x(d[1]);
      }).y(function(d) {
        return y(d[0]);
      });
      area = d3.svg.area().x(function(d) {
        return x(d[1]);
      }).y0(this.height - 1).y1(function(d) {
        return y(d[0]);
      });
      order = this.sort_labels === 'desc' ? -1 : 1;
      data = _.sortBy(data, function(d) {
        return order * d.ymax;
      });
      points = _.map(data, function(d) {
        return d.points;
      });
      if (this.firstrun) {
        this.firstrun = false;
        vis.append("svg:g").attr("class", "x axis").attr("transform", "translate(0," + this.height + ")").transition().duration(this.animate_ms).call(xAxis);
        vis.append("svg:g").attr("class", "y axis").call(yAxis);
        vis.selectAll("path.line").data(points).enter().append('path').attr("d", line).attr('class', function(d, i) {
          return 'line ' + ("h-col-" + (i + 1));
        });
        vis.selectAll("path.area").data(points).enter().append('path').attr("d", area).attr('class', function(d, i) {
          return 'area ' + ("h-col-" + (i + 1));
        });
        if (this.title) {
          title = vis.append('svg:text').attr('class', 'title').attr('transform', "translate(0, -" + this.line_height + ")").text(this.title);
        }
        this.legend = vis.append('svg:g').attr('transform', "translate(0, " + (this.height + this.line_height * 2) + ")").attr('class', 'legend');
      }
      leg_items = this.legend.selectAll('g.l').data(_.first(data, this.num_labels), function(d) {
        return Math.random();
      });
      leg_items.exit().remove();
      litem_enters = leg_items.enter().append('svg:g').attr('transform', function(d, i) {
        return "translate(0, " + (i * _this.line_height) + ")";
      }).attr('class', 'l');
      litem_enters.append('svg:rect').attr('width', 5).attr('height', 5).attr('class', function(d, i) {
        return 'ts-color ' + ("h-col-" + (i + 1));
      });
      litem_enters_text = litem_enters.append('svg:text').attr('dx', 10).attr('dy', 6).attr('class', 'ts-text').text(function(d) {
        return _this.label_formatter(d.label);
      });
      litem_enters_text.append('svg:tspan').attr('class', 'min-tag').attr('dx', 10).text(function(d) {
        return _this.value_format(d.ymin) + "min";
      });
      litem_enters_text.append('svg:tspan').attr('class', 'max-tag').attr('dx', 2).text(function(d) {
        return _this.value_format(d.ymax) + "max";
      });
      vis.transition().ease("linear").duration(this.animate_ms).select(".x.axis").call(xAxis);
      vis.select(".y.axis").call(yAxis);
      vis.selectAll("path.area").data(points).attr("d", area).transition().ease("linear").duration(this.animate_ms);
      return vis.selectAll("path.line").data(points).attr("d", line).transition().ease("linear").duration(this.animate_ms);
    };

    return TimeSeriesView;

  })(Backbone.View);

  Graphene.BarChartView = (function(_super) {

    __extends(BarChartView, _super);

    function BarChartView() {
      this.render = __bind(this.render, this);
      BarChartView.__super__.constructor.apply(this, arguments);
    }

    BarChartView.prototype.tagName = 'div';

    BarChartView.prototype.initialize = function() {
      this.line_height = this.options.line_height || 16;
      this.animate_ms = this.options.animate_ms || 500;
      this.num_labels = this.options.labels || 3;
      this.sort_labels = this.options.labels_sort || 'desc';
      this.display_verticals = this.options.display_verticals || false;
      this.width = this.options.width || 400;
      this.height = this.options.height || 100;
      this.padding = this.options.padding || [this.line_height * 2, 32, this.line_height * (3 + this.num_labels), 32];
      this.title = this.options.title;
      this.label_formatter = this.options.label_formatter || function(label) {
        return label;
      };
      this.firstrun = true;
      this.parent = this.options.parent || '#parent';
      this.null_value = 0;
      this.vis = d3.select(this.parent).append("svg").attr("class", "tsview").attr("width", this.width + (this.padding[1] + this.padding[3])).attr("height", this.height + (this.padding[0] + this.padding[2])).append("g").attr("transform", "translate(" + this.padding[3] + "," + this.padding[0] + ")");
      this.bar_width = Math.min(this.options.bar_width, 1) || 0.50;
      return this.model.bind('change', this.render);
    };

    BarChartView.prototype.render = function() {
      var calculate_bar_width, canvas_height, data, dmax, dmin, points, vis, x, xAxis, xtick_sz, y, yAxis;
      data = this.model.get('data');
      dmax = _.max(data, function(d) {
        return d.ymax;
      });
      dmin = _.min(data, function(d) {
        return d.ymin;
      });
      data = _.sortBy(data, function(d) {
        return 1 * d.ymax;
      });
      points = _.map(data, function(d) {
        return d.points;
      });
      calculate_bar_width = function(points, width, scale) {
        if (scale == null) scale = 1;
        console.log(scale);
        return (width / points[0].length) * scale;
      };
      x = d3.time.scale().domain([data[0].points[0][1], data[0].points[data[0].points.length - 1][1]]).range([0, this.width - calculate_bar_width(points, this.width)]);
      y = d3.scale.linear().domain([dmin.ymin, dmax.ymax]).range([this.height, 0]).nice();
      xtick_sz = this.display_verticals ? -this.height : 0;
      xAxis = d3.svg.axis().scale(x).ticks(4).tickSize(xtick_sz).tickSubdivide(true);
      yAxis = d3.svg.axis().scale(y).ticks(4).tickSize(-this.width).orient("left").tickFormat(d3.format("s"));
      vis = this.vis;
      vis.append("svg:g").attr("class", "x axis").attr("transform", "translate(0," + this.height + ")").transition().duration(this.animate_ms).call(xAxis);
      vis.append("svg:g").attr("class", "y axis").call(yAxis);
      canvas_height = this.height;
      if (this.firstrun) {
        this.firstrun = false;
        vis.selectAll("rect").remove();
        vis.selectAll("rect").data(points[0]).enter().append("rect").attr("x", function(d, i) {
          console.log(x(d[1]));
          return x(d[1]);
        }).attr("y", function(d, i) {
          return canvas_height - (canvas_height - y(d[0]));
        }).attr("width", calculate_bar_width(points, this.width, this.bar_width)).attr("height", function(d, i) {
          return canvas_height - y(d[0]);
        }).attr("class", "h-col-1 area");
      }
      vis.selectAll("rect").data(points[0]).transition().ease("linear").duration(250).attr("x", function(d, i) {
        return x(d[1]);
      }).attr("y", function(d, i) {
        return canvas_height - (canvas_height - y(d[0]));
      }).attr("width", calculate_bar_width(points, this.width, this.bar_width)).attr("height", function(d, i) {
        return canvas_height - y(d[0]);
      }).attr("class", "h-col-1 area");
      vis.transition().ease("linear").duration(this.animate_ms).select(".x.axis").call(xAxis);
      vis.select(".y.axis").call(yAxis);
      return console.log("done drawing");
    };

    return BarChartView;

  })(Backbone.View);

}).call(this);
