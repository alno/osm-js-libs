// Generated by CoffeeScript 1.3.1
(function() {
  var Icon, Layer, UnitFormatters;

  Icon = L.Icon.extend({
    options: {
      popupAnchor: new L.Point(0, -25)
    },
    initialize: function(options) {
      return L.Util.setOptions(this, options);
    },
    createIcon: function() {
      var div, span;
      div = document.createElement('div');
      div.className = 'leaflet-marker-icon weather-icon';
      div.style['margin'] = '-30px 0px 0px -30px';
      div.style['width'] = '60px';
      div.style['height'] = '20px';
      div.style['padding'] = "" + this.options.textOffset + "px 0px 0px 0px";
      div.style['background'] = "url(" + this.options.image + ") no-repeat center top";
      div.style['textAlign'] = 'center';
      span = document.createElement('span');
      span.innerHTML = this.options.text;
      div.appendChild(span);
      return div;
    },
    createShadow: function() {
      return null;
    }
  });

  UnitFormatters = {
    metric: {
      temperature: function(k, digits) {
        var c, p;
        p = Math.pow(10, digits);
        c = k - 273.15;
        return "" + (Math.round(c * p) / p) + "&nbsp;°C";
      },
      speed: function(v) {
        return "" + v + "&nbsp;m/s";
      },
      height: function(v) {
        return "" + v + "&nbsp;mm";
      }
    },
    imperial: {
      temperature: function(k, digits) {
        var f, p;
        p = Math.pow(10, digits);
        f = (k - 273.15) * 1.8 + 32;
        return "" + (Math.round(f * p) / p) + "&nbsp;°F";
      },
      speed: function(v) {
        v = Math.round(v * 2.237);
        return "" + v + "&nbsp;mph";
      },
      height: function(v) {
        v = Math.round(v / 1.27) / 20;
        return "" + v + "&nbsp;in";
      }
    }
  };

  Layer = L.Class.extend({
    defaultI18n: {
      en: {
        currentTemperature: "Temperature",
        maximumTemperature: "Max. temp",
        minimumTemperature: "Min. temp",
        humidity: "Humidity",
        wind: "Wind",
        show: "Snow",
        snow_possible: "Snow possible",
        rain: "Rain",
        rain_possible: "Rain possible",
        icerain: "Ice rain",
        rime: "Rime",
        rime_possible: "Rime",
        clear: "Clear",
        updateDate: "Updated at"
      },
      ru: {
        currentTemperature: "Температура",
        maximumTemperature: "Макс. темп",
        minimumTemperature: "Мин. темп",
        humidity: "Влажность",
        wind: "Ветер",
        show: "Снег",
        snow_possible: "Возможен снег",
        rain: "Дождь",
        rain_possible: "Возможен дождь",
        icerain: "Ледяной дождь",
        rime: "Гололед",
        rime_possible: "Возможен гололед",
        clear: "Ясно",
        updateDate: "Дата обновления"
      }
    },
    includes: L.Mixin.Events,
    initialize: function(options) {
      this.options = options != null ? options : {};
      this.layer = new L.LayerGroup();
      this.sourceUrl = "http://openweathermap.org/data/getrect?type={type}&lat1={minlat}&lat2={maxlat}&lng1={minlon}&lng2={maxlon}";
      this.sourceRequests = {};
      this.clusterWidth = this.options.clusterWidth || 150;
      this.clusterHeight = this.options.clusterHeight || 150;
      this.unitFormatter = UnitFormatters[this.options.units || 'metric'];
      this.type = this.options.type || 'city';
      this.i18n = this.options.i18n || this.defaultI18n[this.options.lang || 'en'];
      this.stationsIcon = this.options.hasOwnProperty('stationsIcon') ? this.options.stationsIcon : true;
      this.temperatureDigits = this.options.temperatureDigits;
      if (this.temperatureDigits == null) {
        this.temperatureDigits = 2;
      }
      return Layer.Utils.checkSunCal();
    },
    onAdd: function(map) {
      this.map = map;
      this.map.addLayer(this.layer);
      this.map.on('moveend', this.update, this);
      return this.update();
    },
    onRemove: function(map) {
      if (this.map !== map) {
        return;
      }
      this.map.off('moveend', this.update, this);
      this.map.removeLayer(this.layer);
      return this.map = void 0;
    },
    getAttribution: function() {
      return 'Weather data provided by <a href="http://openweathermap.org/">OpenWeatherMap</a>.';
    },
    update: function() {
      var req, url, _ref;
      _ref = this.sourceRequests;
      for (url in _ref) {
        req = _ref[url];
        req.abort();
      }
      this.sourceRequests = {};
      return this.updateType(this.type);
    },
    updateType: function(type) {
      var bounds, ne, sw, url,
        _this = this;
      bounds = this.map.getBounds();
      sw = bounds.getSouthWest();
      ne = bounds.getNorthEast();
      url = this.sourceUrl.replace('{type}', type).replace('{minlat}', sw.lat).replace('{maxlat}', ne.lat).replace('{minlon}', sw.lng).replace('{maxlon}', ne.lng);
      return this.sourceRequests[type] = Layer.Utils.requestJsonp(url, function(data) {
        var cells, key, ll, p, st, _i, _len, _ref;
        delete _this.sourceRequests[type];
        _this.map.removeLayer(_this.layer);
        _this.layer.clearLayers();
        cells = {};
        _ref = data.list;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          st = _ref[_i];
          ll = new L.LatLng(st.lat, st.lng);
          p = _this.map.latLngToLayerPoint(ll);
          key = "" + (Math.round(p.x / _this.clusterWidth)) + "_" + (Math.round(p.y / _this.clusterHeight));
          if (!cells[key] || parseInt(cells[key].rang) < parseInt(st.rang)) {
            cells[key] = st;
          }
        }
        for (key in cells) {
          st = cells[key];
          _this.layer.addLayer(_this.buildMarker(st, new L.LatLng(st.lat, st.lng)));
        }
        return _this.map.addLayer(_this.layer);
      });
    },
    buildMarker: function(st, ll) {
      var marker, markerIcon, popupContent, typeIcon, weatherIcon, weatherText;
      weatherText = this.weatherText(st);
      weatherIcon = this.weatherIcon(st);
      popupContent = "<div class=\"weather-place\">";
      popupContent += "<img height=\"38\" width=\"45\" style=\"border: none; float: right;\" alt=\"" + weatherText + "\" src=\"" + weatherIcon + "\" />";
      popupContent += "<h3><a href=\"" + (this.buildUrl(st)) + "\" target=\"_blank\">" + st.name + "</a></h3>";
      popupContent += "<p>" + weatherText + "</p>";
      popupContent += "<p>";
      popupContent += "" + this.i18n.currentTemperature + ":&nbsp;" + (this.unitFormatter.temperature(st.temp, this.temperatureDigits)) + "<br />";
      if (st.temp_max) {
        popupContent += "" + this.i18n.maximumTemperature + ":&nbsp;" + (this.unitFormatter.temperature(st.temp_max, this.temperatureDigits)) + "<br />";
      }
      if (st.temp_min) {
        popupContent += "" + this.i18n.minimumTemperature + ":&nbsp;" + (this.unitFormatter.temperature(st.temp_min, this.temperatureDigits)) + "<br />";
      }
      if (st.humidity) {
        popupContent += "" + this.i18n.humidity + ":&nbsp;" + st.humidity + "<br />";
      }
      popupContent += "" + this.i18n.wind + ":&nbsp;" + (this.unitFormatter.speed(st.wind_ms)) + "<br />";
      if (st.dt) {
        popupContent += "" + this.i18n.updateDate + ":&nbsp;" + (this.formatTimestamp(st.dt)) + "<br />";
      }
      popupContent += "</p>";
      popupContent += "</div>";
      typeIcon = this.typeIcon(st);
      markerIcon = this.stationsIcon && typeIcon ? new Icon({
        image: typeIcon,
        text: "" + (this.unitFormatter.temperature(st.temp, this.temperatureDigits)),
        textOffset: 30
      }) : new Icon({
        image: weatherIcon,
        text: "" + (this.unitFormatter.temperature(st.temp, this.temperatureDigits)),
        textOffset: 45
      });
      marker = new L.Marker(ll, {
        icon: markerIcon
      });
      marker.bindPopup(popupContent);
      return marker;
    },
    formatTimestamp: function(ts) {
      var d, date, hh, m, mm;
      date = new Date(ts * 1000);
      m = date.getMonth() + 1;
      if (m < 10) {
        m = '0' + m;
      }
      d = date.getDate();
      if (d < 10) {
        d = '0' + d;
      }
      hh = date.getHours();
      mm = date.getMinutes();
      if (mm < 10) {
        mm = '0' + mm;
      }
      return "" + (date.getFullYear()) + "-" + m + "-" + d + " " + hh + ":" + mm;
    },
    buildUrl: function(st) {
      if (st.datatype === 'station') {
        return "http://openweathermap.org/station/" + st.id;
      } else {
        return "http://openweathermap.org/city/" + st.id;
      }
    },
    weatherIcon: function(st) {
      var cl, day, i, img, _i, _len, _ref;
      day = this.dayTime(st);
      cl = st.cloud;
      img = 'transparent';
      if (cl < 25 && cl >= 0) {
        img = '01' + day;
      }
      if (cl < 50 && cl >= 25) {
        img = '02' + day;
      }
      if (cl < 75 && cl >= 50) {
        img = '03' + day;
      }
      if (cl >= 75) {
        img = '04';
      }
      if (st.prsp_type === '1' && st.prcp > 0) {
        img = '13';
      }
      if (st.prsp_type === '4' && st.prcp > 0) {
        img = '09';
      }
      _ref = ['23', '24', '26', '27', '28', '29', '33', '38', '42'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        if (st.prsp_type === i) {
          img = '09';
        }
      }
      return "http://openweathermap.org/images/icons60/" + img + ".png";
    },
    typeIcon: function(st) {
      if (st.datatype === 'station') {
        if (st.type === '1') {
          return "http://openweathermap.org/images/list-icon-3.png";
        } else if (st.type === '2') {
          return "http://openweathermap.org/images/list-icon-2.png";
        }
      }
    },
    weatherText: function(st) {
      if (st.prsp_type === '1') {
        if (st.prcp !== 0 && st.prcp > 0) {
          return "" + this.i18n.snow + "&nbsp;(" + (this.unitFormatter.height(st.prcp)) + ")";
        } else {
          return this.i18n.snow_possible;
        }
      } else if (st.prsp_type === '2') {
        if (st.prcp !== 0 && st.prcp > 0) {
          return "" + this.i18n.rime + "&nbsp;(" + (this.unitFormatter.height(st.prcp)) + ")";
        } else {
          return this.i18n.rime_possible;
        }
      } else if (st.prsp_type === '3') {
        return this.i18n.icerain;
      } else if (st.prsp_type === '4') {
        if (st.prcp !== 0 && st.prcp > 0) {
          return "" + this.i18n.rain + "&nbsp;(" + (this.unitFormatter.height(st.prcp)) + ")";
        } else {
          return this.i18n.rain_possible;
        }
      } else {
        return this.i18n.clear;
      }
    },
    dayTime: function(st) {
      var dt, times;
      if (typeof SunCalc === "undefined" || SunCalc === null) {
        return 'd';
      }
      dt = new Date();
      times = SunCalc.getTimes(dt, st.lat, st.lng);
      if (dt > times.sunrise && dt < times.sunset) {
        return 'd';
      } else {
        return 'n';
      }
    }
  });

  Layer.Utils = {
    callbacks: {},
    callbackCounter: 0,
    checkSunCal: function() {
      var el;
      if (typeof SunCalc !== "undefined" && SunCalc !== null) {
        return;
      }
      el = document.createElement('script');
      el.src = 'https://raw.github.com/mourner/suncalc/master/suncalc.js';
      el.type = 'text/javascript';
      return document.getElementsByTagName('body')[0].appendChild(el);
    },
    requestJsonp: function(url, cb) {
      var abort, callback, counter, delim, el,
        _this = this;
      el = document.createElement('script');
      counter = (this.callbackCounter += 1);
      callback = "OsmJs.Weather.LeafletLayer.Utils.callbacks[" + counter + "]";
      abort = function() {
        if (el.parentNode) {
          return el.parentNode.removeChild(el);
        }
      };
      this.callbacks[counter] = function(data) {
        delete _this.callbacks[counter];
        return cb(data);
      };
      delim = url.indexOf('?') >= 0 ? '&' : '?';
      el.src = "" + url + delim + "callback=" + callback;
      el.type = 'text/javascript';
      document.getElementsByTagName('body')[0].appendChild(el);
      return {
        abort: abort
      };
    }
  };

  if (!this.OsmJs) {
    this.OsmJs = {};
  }

  if (!this.OsmJs.Weather) {
    this.OsmJs.Weather = {};
  }

  this.OsmJs.Weather.LeafletLayer = Layer;

}).call(this);
