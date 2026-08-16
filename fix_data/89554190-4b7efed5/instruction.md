## Add Buienradar support to the weather module

MagicMirror needs a server-side Buienradar provider for weather forecasts in the Netherlands and Belgium without an API key. Users select it with `weatherProvider: "buienradar"` and use `current`, `forecast`, `daily`, or `hourly` mode.

Follow the CommonJS export and public lifecycle contract of existing server-side weather providers. Construct the provider from one configuration object and expose `setCallbacks(onData, onError)`, `initialize()`, `start()`, and `stop()`. Starting fetches repeatedly at the configured interval. After stop, an in-flight response must not emit data or schedule another request. Every lifecycle method must be safe before or after initialization.

Apply user configuration over these defaults:

| Setting | Default |
| --- | --- |
| `apiBase` | `https://forecast.buienradar.nl/2.0/forecast` |
| `locationId` | `null` |
| `type` | `current` |
| `maxEntries` | `5` |
| `updateInterval` | `10 * 60 * 1000` milliseconds |

Expose the merged values through `config`. Initialization without `locationId` reports an error and makes no request.

Fetch `{apiBase}/{locationId}` as a valid forecast URL and ensure responses are not cached. Route HTTP, JSON, and processing failures only to the error callback. Each processing error contains a readable message and a nonempty translation key.

The response has `location.name` and a `days` array. A day may contain `date`, `mintemp`, `maxtemp`, `humidity`, `windspeedms`, `winddirectiondegrees`, `precipitationmm`, `precipitation`, `sunrise`, `sunset`, `iconcode`, and `hours`. An hour may contain `datetime`, `temperature`, `feeltemperature`, the same humidity, wind, precipitation, and icon fields. Expose `location.name` through `locationName`. Missing, non-array, or empty `days` is an error.

Map source values to the corresponding weather-module names: `windspeedms` to `windSpeed`, `winddirectiondegrees` to `windFromDirection`, `precipitationmm` to `precipitationAmount`, `precipitation` to `precipitationProbability`, `feeltemperature` to `feelsLikeTemp`, and minimum/maximum temperatures to `minTemperature`/`maxTemperature`.

For `current`, consider all valid hourly records across every day and choose the timestamp nearest to the current time. Return its `date`, temperature, humidity, wind, precipitation, and weather type together with that hour's parent-day minimum, maximum, sunrise, and sunset. Include `precipitationUnits: "mm"` when an amount exists.

For `forecast` and `daily`, return identical day records. Hourly results contain at most `maxEntries` usable records in their day-and-hour source order. Daily records include `date`, minimum, maximum, humidity, wind, precipitation, sunrise, sunset, and weather type. Hourly records include `date`, `temperature`, `feelsLikeTemp`, humidity, wind, precipitation, and weather type.

Numeric output fields must resolve to finite numbers while preserving zero and negative values; omit unusable optional numeric values. Emit valid `Date` instances using a consistent interpretation of source timestamps. Skip records with invalid required dates, but omit invalid optional sunrise or sunset values. Missing optional numeric values do not invalidate records.

If no usable record remains for the selected mode, report an error and never invoke the data callback. Unsupported modes behave likewise.

Returned objects must remain interchangeable with those from other weather providers: expose only normalized module fields, preserve source data, and avoid requiring downstream Buienradar-specific parsing or rendering.

Convert icon codes case-insensitively using this complete mapping: `a=day-sunny,aa=night-clear,b=day-cloudy,bb=night-alt-cloudy,c=cloudy,cc=cloudy,d=day-fog,dd=night-fog,f=day-sprinkle,ff=night-alt-sprinkle,g=day-storm-showers,gg=night-alt-storm-showers,h=day-rain,hh=night-alt-rain,i=day-rain-mix,ii=night-alt-rain-mix,j=day-cloudy,jj=night-alt-cloudy,k=day-showers,kk=night-alt-showers,l=showers,ll=showers,m=sprinkle,mm=sprinkle,n=day-haze,nn=night-fog,o=day-cloudy,oo=night-alt-cloudy,p=cloudy,pp=cloudy,q=showers,qq=showers,r=day-cloudy,rr=night-alt-cloudy,s=thunderstorm,ss=thunderstorm,t=snow,tt=snow,u=day-snow,uu=night-alt-snow,v=snow,vv=snow,w=rain-mix,ww=rain-mix`. Missing or unknown codes produce `null`. This applies equally to day and hour records and preserves consistent rendering across supported modes.
