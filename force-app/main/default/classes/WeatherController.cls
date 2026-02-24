/**
 * @description Backend controller for the Next-Gen Weather Forecast LWC.
 * Performs REST GET callouts to OpenWeatherMap API for current weather
 * and 7-day forecast data.
 *
 * Requires a Remote Site Setting for: https://api.openweathermap.org
 * Requires a Custom Metadata or Custom Setting to store the API key,
 * or you can set it directly in the API_KEY constant for development.
 *
 * @author Copilot
 * @since 2026-02-24
 */
public with sharing class WeatherController {

    /** @description OpenWeatherMap API key. Replace with your own key. */
    private static final String API_KEY = 'YOUR_API_KEY_HERE';

    /** @description Base URL for OpenWeatherMap API. */
    private static final String BASE_URL = 'https://api.openweathermap.org';

    /**
     * @description Wrapper for current weather data returned to the LWC.
     */
    public class WeatherResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public CurrentWeather current;
        @AuraEnabled public List<DailyForecast> daily;
        @AuraEnabled public String locationName;
        @AuraEnabled public String country;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lon;
    }

    /**
     * @description Current weather snapshot.
     */
    public class CurrentWeather {
        @AuraEnabled public Decimal temp;
        @AuraEnabled public Decimal feelsLike;
        @AuraEnabled public Decimal tempMin;
        @AuraEnabled public Decimal tempMax;
        @AuraEnabled public Integer humidity;
        @AuraEnabled public Decimal windSpeed;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
        @AuraEnabled public String main;
        @AuraEnabled public Integer pressure;
        @AuraEnabled public Integer visibility;
        @AuraEnabled public Long sunrise;
        @AuraEnabled public Long sunset;
    }

    /**
     * @description Single day in the 7-day forecast.
     */
    public class DailyForecast {
        @AuraEnabled public String dayName;
        @AuraEnabled public String dateStr;
        @AuraEnabled public Decimal tempHigh;
        @AuraEnabled public Decimal tempLow;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
        @AuraEnabled public String main;
        @AuraEnabled public Integer humidity;
        @AuraEnabled public Decimal windSpeed;
        @AuraEnabled public Decimal pop;
    }

    /**
     * @description Fetch current weather and 7-day forecast for a location.
     * Accepts city name, "City, State", "City, Country", or zip code.
     * @param location The search query (e.g., "San Francisco", "94105").
     * @return WeatherResult with current conditions and daily forecast.
     */
    @AuraEnabled
    public static WeatherResult getForecast(String location) {
        WeatherResult result = new WeatherResult();
        result.success = false;
        result.daily = new List<DailyForecast>();

        if (String.isBlank(location)) {
            result.errorMessage = 'Please enter a location to search.';
            return result;
        }

        try {
            // Step 1: Geocode the location to get lat/lon
            Map<String, Decimal> coords = geocodeLocation(location.trim());
            if (coords == null) {
                result.errorMessage = 'Location not found. Try "City, Country" or a zip code.';
                return result;
            }

            Decimal lat = coords.get('lat');
            Decimal lon = coords.get('lon');
            String resolvedName = '';
            String resolvedCountry = '';

            // Extract name from geocode response if available
            if (coords.containsKey('nameHash')) {
                // We store name info in a separate call — get it from geo response
            }

            // Step 2: Get current weather using lat/lon
            String currentUrl = BASE_URL + '/data/2.5/weather?lat=' + lat
                + '&lon=' + lon + '&appid=' + API_KEY + '&units=metric';

            HttpResponse currentResp = makeCallout(currentUrl);
            if (currentResp.getStatusCode() != 200) {
                result.errorMessage = 'Unable to fetch current weather (HTTP ' + currentResp.getStatusCode() + ').';
                return result;
            }

            Map<String, Object> currentData = (Map<String, Object>) JSON.deserializeUntyped(currentResp.getBody());
            result.current = parseCurrentWeather(currentData);
            result.locationName = (String) currentData.get('name');
            Map<String, Object> sys = (Map<String, Object>) currentData.get('sys');
            if (sys != null) {
                result.country = (String) sys.get('country');
            }
            result.lat = lat;
            result.lon = lon;

            // Step 3: Get 7-day forecast using One Call API 3.0
            // Fallback: use 5-day/3-hour forecast and aggregate by day
            String forecastUrl = BASE_URL + '/data/2.5/forecast?lat=' + lat
                + '&lon=' + lon + '&appid=' + API_KEY + '&units=metric';

            HttpResponse forecastResp = makeCallout(forecastUrl);
            if (forecastResp.getStatusCode() == 200) {
                Map<String, Object> forecastData = (Map<String, Object>) JSON.deserializeUntyped(forecastResp.getBody());
                result.daily = parseDailyForecast(forecastData);
            }

            result.success = true;

        } catch (Exception e) {
            result.errorMessage = 'An error occurred: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'WeatherController.getForecast error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * @description Geocode a location string to lat/lon coordinates.
     * @param location City name, zip code, or "City, Country" format.
     * @return Map with 'lat' and 'lon' keys, or null if not found.
     */
    @TestVisible
    private static Map<String, Decimal> geocodeLocation(String location) {
        String endpoint;

        // Check if input is a zip/postal code (digits only, or digits+dash for US)
        if (location.isNumeric() || Pattern.matches('\\d{5}(-\\d{4})?', location)) {
            endpoint = BASE_URL + '/geo/1.0/zip?zip=' + EncodingUtil.urlEncode(location, 'UTF-8')
                + '&appid=' + API_KEY;
        } else {
            endpoint = BASE_URL + '/geo/1.0/direct?q=' + EncodingUtil.urlEncode(location, 'UTF-8')
                + '&limit=1&appid=' + API_KEY;
        }

        HttpResponse resp = makeCallout(endpoint);
        if (resp.getStatusCode() != 200) {
            return null;
        }

        String body = resp.getBody();
        Map<String, Decimal> coords = new Map<String, Decimal>();

        // Zip endpoint returns an object; direct endpoint returns an array
        if (body.startsWith('[')) {
            List<Object> results = (List<Object>) JSON.deserializeUntyped(body);
            if (results.isEmpty()) {
                return null;
            }
            Map<String, Object> first = (Map<String, Object>) results[0];
            coords.put('lat', (Decimal) first.get('lat'));
            coords.put('lon', (Decimal) first.get('lon'));
        } else if (body.startsWith('{')) {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (!data.containsKey('lat')) {
                return null;
            }
            coords.put('lat', (Decimal) data.get('lat'));
            coords.put('lon', (Decimal) data.get('lon'));
        } else {
            return null;
        }

        return coords;
    }

    /**
     * @description Parse current weather JSON into a CurrentWeather object.
     * @param data Deserialized JSON map from the weather API.
     * @return Populated CurrentWeather instance.
     */
    @TestVisible
    private static CurrentWeather parseCurrentWeather(Map<String, Object> data) {
        CurrentWeather cw = new CurrentWeather();

        Map<String, Object> main = (Map<String, Object>) data.get('main');
        if (main != null) {
            cw.temp = toDecimal(main.get('temp'));
            cw.feelsLike = toDecimal(main.get('feels_like'));
            cw.tempMin = toDecimal(main.get('temp_min'));
            cw.tempMax = toDecimal(main.get('temp_max'));
            cw.humidity = toInteger(main.get('humidity'));
            cw.pressure = toInteger(main.get('pressure'));
        }

        Map<String, Object> wind = (Map<String, Object>) data.get('wind');
        if (wind != null) {
            cw.windSpeed = toDecimal(wind.get('speed'));
        }

        cw.visibility = toInteger(data.get('visibility'));

        List<Object> weatherList = (List<Object>) data.get('weather');
        if (weatherList != null && !weatherList.isEmpty()) {
            Map<String, Object> weather = (Map<String, Object>) weatherList[0];
            cw.description = (String) weather.get('description');
            cw.icon = (String) weather.get('icon');
            cw.main = (String) weather.get('main');
        }

        Map<String, Object> sys = (Map<String, Object>) data.get('sys');
        if (sys != null) {
            cw.sunrise = toLong(sys.get('sunrise'));
            cw.sunset = toLong(sys.get('sunset'));
        }

        return cw;
    }

    /**
     * @description Parse 5-day/3-hour forecast into daily aggregates.
     * Groups by date and picks high/low temps for each day.
     * @param data Deserialized JSON map from the forecast API.
     * @return List of up to 7 DailyForecast entries.
     */
    @TestVisible
    private static List<DailyForecast> parseDailyForecast(Map<String, Object> data) {
        List<DailyForecast> dailyList = new List<DailyForecast>();
        List<Object> entries = (List<Object>) data.get('list');
        if (entries == null) {
            return dailyList;
        }

        // Group entries by date
        Map<String, List<Map<String, Object>>> byDate = new Map<String, List<Map<String, Object>>>();
        List<String> dateOrder = new List<String>();

        for (Object entry : entries) {
            Map<String, Object> item = (Map<String, Object>) entry;
            String dtTxt = (String) item.get('dt_txt');
            if (dtTxt == null) {
                continue;
            }
            String dateKey = dtTxt.substring(0, 10); // "2026-02-24"

            if (!byDate.containsKey(dateKey)) {
                byDate.put(dateKey, new List<Map<String, Object>>());
                dateOrder.add(dateKey);
            }
            byDate.get(dateKey).add(item);
        }

        // Build daily aggregates (up to 7 days)
        Integer count = 0;
        for (String dateKey : dateOrder) {
            if (count >= 7) {
                break;
            }

            List<Map<String, Object>> dayEntries = byDate.get(dateKey);
            DailyForecast df = new DailyForecast();

            // Parse date for display
            Date d = Date.valueOf(dateKey);
            Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
            df.dayName = dt.format('EEE');
            df.dateStr = dt.format('MMM d');

            Decimal high = -999;
            Decimal low = 999;
            Decimal totalHumidity = 0;
            Decimal totalWind = 0;
            Decimal maxPop = 0;
            String mainWeather = '';
            String iconCode = '';

            for (Map<String, Object> item : dayEntries) {
                Map<String, Object> mainData = (Map<String, Object>) item.get('main');
                if (mainData != null) {
                    Decimal tempMax = toDecimal(mainData.get('temp_max'));
                    Decimal tempMin = toDecimal(mainData.get('temp_min'));
                    if (tempMax != null && tempMax > high) {
                        high = tempMax;
                    }
                    if (tempMin != null && tempMin < low) {
                        low = tempMin;
                    }
                    totalHumidity += toDecimal(mainData.get('humidity'));
                }

                Map<String, Object> windData = (Map<String, Object>) item.get('wind');
                if (windData != null) {
                    totalWind += toDecimal(windData.get('speed'));
                }

                Decimal pop = toDecimal(item.get('pop'));
                if (pop != null && pop > maxPop) {
                    maxPop = pop;
                }

                List<Object> weatherList = (List<Object>) item.get('weather');
                if (weatherList != null && !weatherList.isEmpty()) {
                    Map<String, Object> weather = (Map<String, Object>) weatherList[0];
                    // Use midday reading for representative icon
                    String timePart = ((String) item.get('dt_txt')).substring(11, 13);
                    if (timePart == '12' || String.isBlank(mainWeather)) {
                        mainWeather = (String) weather.get('main');
                        iconCode = (String) weather.get('icon');
                        df.description = (String) weather.get('description');
                    }
                }
            }

            df.tempHigh = (high > -999) ? high.setScale(1) : null;
            df.tempLow = (low < 999) ? low.setScale(1) : null;
            df.humidity = (Integer) (totalHumidity / dayEntries.size()).round(System.RoundingMode.HALF_UP);
            df.windSpeed = (totalWind / dayEntries.size()).setScale(1);
            df.pop = (maxPop * 100).setScale(0);
            df.main = mainWeather;
            df.icon = iconCode;

            dailyList.add(df);
            count++;
        }

        return dailyList;
    }

    /**
     * @description Perform an HTTP GET callout.
     * @param url The endpoint URL.
     * @return HttpResponse from the callout.
     */
    @TestVisible
    private static HttpResponse makeCallout(String url) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(10000);
        return http.send(req);
    }

    /**
     * @description Safely cast Object to Decimal.
     * @param val The value to convert.
     * @return Decimal value, or null.
     */
    private static Decimal toDecimal(Object val) {
        if (val == null) {
            return 0;
        }
        if (val instanceof Decimal) {
            return (Decimal) val;
        }
        if (val instanceof Integer) {
            return Decimal.valueOf((Integer) val);
        }
        if (val instanceof Long) {
            return Decimal.valueOf((Long) val);
        }
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * @description Safely cast Object to Integer.
     * @param val The value to convert.
     * @return Integer value, or 0.
     */
    private static Integer toInteger(Object val) {
        if (val == null) {
            return 0;
        }
        if (val instanceof Integer) {
            return (Integer) val;
        }
        try {
            return Integer.valueOf(val);
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * @description Safely cast Object to Long.
     * @param val The value to convert.
     * @return Long value, or null.
     */
    private static Long toLong(Object val) {
        if (val == null) {
            return null;
        }
        if (val instanceof Long) {
            return (Long) val;
        }
        if (val instanceof Integer) {
            return (Long) val;
        }
        try {
            return Long.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return null;
        }
    }
}
