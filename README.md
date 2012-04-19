# JavaScript libraries for OpenStreetMap applications

## Usage

### Validators Leaflet layer

Add validators layer to your Leaflet map by:

    map.addLayer(new OsmJs.Validators.LeafletLayer(config))

Where example config is:

    {
      validators: [{
        "name": "Отладочный валидатор",
        "url": "http://alno.name:4567/validate?minlat={minlat}&minlon={minlon}&maxlat={maxlat}&maxlon={maxlon}",
        "offset_limit": true,
        "jsonp": true,
        "types": {
          "test_error": {"text": "Тестовая ошибка"}
        }
      }]
    }

## Building

Install coffee-script first:

    sudo npm install --global coffee-script

Then call:

    cake build

That's all, now you have your updated library in dist/

## Contributors

* Alexey Noskov ({alno}[https://github.com/alno])

Copyright © 2012 Alexey Noskov, released under the {MIT license}[http://www.opensource.org/licenses/MIT]
