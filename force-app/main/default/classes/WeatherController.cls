/**
 * @description Backend controller for the Next-Gen Weather Forecast LWC.
 * Performs REST GET callouts to Open-Meteo (Free, No API Key) for current weather,
 * hourly forecast, and 7-day forecast data.
 *
 * Requires Remote Site Settings for: 
 * - https://api.open-meteo.com
 * - https://geocoding-api.open-meteo.com
 * - https://api.zippopotam.us
 *
 * @author Copilot
 * @since 2026-02-24
 */
public with sharing class WeatherController {

    public class WeatherResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public CurrentWeather current;
        @AuraEnabled public List<HourlyForecast> hourly;
        @AuraEnabled public List<DailyForecast> daily;
        @AuraEnabled public String locationName;
        @AuraEnabled public String country;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lon;
    }

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
        @AuraEnabled public Boolean isDay;
        @AuraEnabled public Integer weatherCode;
    }

    public class HourlyForecast {
        @AuraEnabled public Long timeUnix;
        @AuraEnabled public String timeStr;
        @AuraEnabled public Decimal temp;
        @AuraEnabled public String icon;
        @AuraEnabled public String description;
    }

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

    @AuraEnabled
    public static WeatherResult getForecast(String location) {
        WeatherResult result = new WeatherResult();
        result.success = false;

        if (String.isBlank(location)) {
            result.errorMessage = 'Please enter a location to search.';
            return result;
        }

        try {
            Map<String, Object> geoInfo = geocodeLocation(location.trim());
            if (geoInfo == null) {
                result.errorMessage = 'Location not found. Try "City, Country" or a zip code.';
                return result;
            }

            Decimal lat = (Decimal) geoInfo.get('lat');
            Decimal lon = (Decimal) geoInfo.get('lon');
            String locName = (String) geoInfo.get('name');
            String country = (String) geoInfo.get('country');

            return fetchWeatherByCoords(lat, lon, locName, country);
        } catch (Exception e) {
            result.errorMessage = 'An error occurred: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'WeatherController.getForecast error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
        return result;
    }

    @AuraEnabled
    public static WeatherResult getForecastByCoordinates(Decimal lat, Decimal lon) {
        WeatherResult result = new WeatherResult();
        result.success = false;

        try {
            // Reverse geocode to get city name
            String endpoint = 'https://geocoding-api.open-meteo.com/v1/reverse?latitude=' + lat + '&longitude=' + lon + '&count=1';
            HttpResponse resp = makeCallout(endpoint);
            String locName = 'Current Location';
            String country = '';
            
            if (resp.getStatusCode() == 200) {
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                List<Object> results = (List<Object>) data.get('results');
                if (results != null && !results.isEmpty()) {
                    Map<String, Object> first = (Map<String, Object>) results[0];
                    locName = (String) first.get('name');
                    country = (String) first.get('country_code');
                }
            }

            return fetchWeatherByCoords(lat, lon, locName, country);
        } catch (Exception e) {
            result.errorMessage = 'An error occurred: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'WeatherController.getForecastByCoordinates error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
        return result;
    }

    private static WeatherResult fetchWeatherByCoords(Decimal lat, Decimal lon, String locName, String country) {
        WeatherResult result = new WeatherResult();
        result.success = false;
        result.locationName = locName;
        result.country = country;
        result.lat = lat;
        result.lon = lon;
        result.hourly = new List<HourlyForecast>();
        result.daily = new List<DailyForecast>();

        String weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=' + lat + '&longitude=' + lon 
            + '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,cloud_cover,surface_pressure,wind_speed_10m'
            + '&hourly=temperature_2m,weather_code,is_day'
            + '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max'
            + '&timezone=auto&timeformat=unixtime&forecast_days=7&forecast_hours=24';

        HttpResponse weatherResp = makeCallout(weatherUrl);
        if (weatherResp.getStatusCode() != 200) {
            result.errorMessage = 'Unable to fetch weather data (HTTP ' + weatherResp.getStatusCode() + ').';
            return result;
        }

        Map<String, Object> weatherData = (Map<String, Object>) JSON.deserializeUntyped(weatherResp.getBody());
        
        // Parse Current
        Map<String, Object> currentData = (Map<String, Object>) weatherData.get('current');
        result.current = parseCurrentWeather(currentData);
        
        // Parse Hourly
        Map<String, Object> hourlyData = (Map<String, Object>) weatherData.get('hourly');
        result.hourly = parseHourlyForecast(hourlyData);

        // Parse Daily
        Map<String, Object> dailyData = (Map<String, Object>) weatherData.get('daily');
        result.daily = parseDailyForecast(dailyData);

        if (!result.daily.isEmpty()) {
            result.current.tempMax = result.daily[0].tempHigh;
            result.current.tempMin = result.daily[0].tempLow;
            
            List<Object> sunrises = (List<Object>) dailyData.get('sunrise');
            List<Object> sunsets = (List<Object>) dailyData.get('sunset');
            if (sunrises != null && !sunrises.isEmpty()) result.current.sunrise = toLong(sunrises[0]);
            if (sunsets != null && !sunsets.isEmpty()) result.current.sunset = toLong(sunsets[0]);
        }

        result.success = true;
        return result;
    }

    @TestVisible
    private static Map<String, Object> geocodeLocation(String location) {
        Map<String, Object> geoInfo = new Map<String, Object>();

        Matcher m = Pattern.compile('\\b\\d{5}\\b').matcher(location);
        if (m.find()) {
            String zipParam = m.group(0);
            String endpoint = 'https://api.zippopotam.us/us/' + EncodingUtil.urlEncode(zipParam, 'UTF-8');
            
            HttpResponse resp = makeCallout(endpoint);
            if (resp.getStatusCode() == 200) {
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                List<Object> places = (List<Object>) data.get('places');
                if (places != null && !places.isEmpty()) {
                    Map<String, Object> place = (Map<String, Object>) places[0];
                    geoInfo.put('lat', Decimal.valueOf((String) place.get('latitude')));
                    geoInfo.put('lon', Decimal.valueOf((String) place.get('longitude')));
                    geoInfo.put('name', (String) place.get('place name'));
                    geoInfo.put('country', (String) data.get('country abbreviation'));
                    return geoInfo;
                }
            }
        }
        
        String endpoint = 'https://geocoding-api.open-meteo.com/v1/search?name=' + EncodingUtil.urlEncode(location, 'UTF-8') + '&count=1';
        
        HttpResponse resp = makeCallout(endpoint);
        if (resp.getStatusCode() != 200) return null;
        
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
        List<Object> results = (List<Object>) data.get('results');
        if (results == null || results.isEmpty()) return null;
        
        Map<String, Object> first = (Map<String, Object>) results[0];
        geoInfo.put('lat', toDecimal(first.get('latitude')));
        geoInfo.put('lon', toDecimal(first.get('longitude')));
        geoInfo.put('name', (String) first.get('name'));
        geoInfo.put('country', (String) first.get('country_code'));
        return geoInfo;
    }

    @TestVisible
    private static CurrentWeather parseCurrentWeather(Map<String, Object> data) {
        CurrentWeather cw = new CurrentWeather();
        if (data == null) return cw;

        cw.temp = toDecimal(data.get('temperature_2m'));
        cw.feelsLike = toDecimal(data.get('apparent_temperature'));
        cw.humidity = toInteger(data.get('relative_humidity_2m'));
        cw.pressure = toInteger(data.get('surface_pressure'));
        cw.windSpeed = toDecimal(data.get('wind_speed_10m'));
        cw.visibility = 10000;

        Integer weatherCode = toInteger(data.get('weather_code'));
        Boolean isDay = toInteger(data.get('is_day')) == 1;
        
        cw.weatherCode = weatherCode;
        cw.isDay = isDay;

        Map<String, String> wmo = mapWmoCode(weatherCode, isDay);
        cw.main = wmo.get('main');
        cw.description = wmo.get('description');
        cw.icon = wmo.get('icon');

        return cw;
    }

    @TestVisible
    private static List<HourlyForecast> parseHourlyForecast(Map<String, Object> data) {
        List<HourlyForecast> hourlyList = new List<HourlyForecast>();
        if (data == null) return hourlyList;

        List<Object> times = (List<Object>) data.get('time');
        List<Object> temps = (List<Object>) data.get('temperature_2m');
        List<Object> codes = (List<Object>) data.get('weather_code');
        List<Object> isDays = (List<Object>) data.get('is_day');

        if (times == null) return hourlyList;

        Long currentUnix = Datetime.now().getTime() / 1000;

        for (Integer i = 0; i < times.size(); i++) {
            Long unixTime = toLong(times[i]);
            
            if (unixTime >= currentUnix - 3600) {
                HourlyForecast hf = new HourlyForecast();
                hf.timeUnix = unixTime;
                
                Datetime dt = Datetime.newInstance(unixTime * 1000);
                hf.timeStr = dt.format('h a');
                
                hf.temp = temps != null && i < temps.size() ? toDecimal(temps[i]) : null;
                
                Integer code = codes != null && i < codes.size() ? toInteger(codes[i]) : 0;
                Boolean isDay = isDays != null && i < isDays.size() ? toInteger(isDays[i]) == 1 : true;
                
                Map<String, String> wmo = mapWmoCode(code, isDay);
                hf.icon = wmo.get('icon');
                hf.description = wmo.get('description');
                
                hourlyList.add(hf);
                
                if (hourlyList.size() >= 24) break;
            }
        }

        return hourlyList;
    }

    @TestVisible
    private static List<DailyForecast> parseDailyForecast(Map<String, Object> data) {
        List<DailyForecast> dailyList = new List<DailyForecast>();
        if (data == null) return dailyList;

        List<Object> times = (List<Object>) data.get('time');
        List<Object> codes = (List<Object>) data.get('weather_code');
        List<Object> maxTemps = (List<Object>) data.get('temperature_2m_max');
        List<Object> minTemps = (List<Object>) data.get('temperature_2m_min');
        List<Object> pops = (List<Object>) data.get('precipitation_probability_max');

        if (times == null) return dailyList;

        for (Integer i = 0; i < times.size(); i++) {
            DailyForecast df = new DailyForecast();
            
            Long unixTime = toLong(times[i]);
            Datetime dt = Datetime.newInstance(unixTime * 1000);
            df.dayName = dt.format('EEE');
            df.dateStr = dt.format('MMM d');

            df.tempHigh = maxTemps != null && i < maxTemps.size() ? toDecimal(maxTemps[i]) : null;
            df.tempLow = minTemps != null && i < minTemps.size() ? toDecimal(minTemps[i]) : null;
            df.pop = pops != null && i < pops.size() ? toDecimal(pops[i]) : 0;
            
            Integer code = codes != null && i < codes.size() ? toInteger(codes[i]) : 0;
            Map<String, String> wmo = mapWmoCode(code, true);
            df.main = wmo.get('main');
            df.description = wmo.get('description');
            df.icon = wmo.get('icon');
            
            df.humidity = 50;
            df.windSpeed = 0;

            dailyList.add(df);
        }

        return dailyList;
    }

    private static Map<String, String> mapWmoCode(Integer code, Boolean isDay) {
        Map<String, String> res = new Map<String, String>();
        String d = isDay ? 'd' : 'n';
        
        if (code == 0) {
            res.put('main', 'Clear'); res.put('description', 'clear sky'); res.put('icon', '01' + d);
        } else if (code == 1) {
            res.put('main', 'Clouds'); res.put('description', 'mainly clear'); res.put('icon', '02' + d);
        } else if (code == 2) {
            res.put('main', 'Clouds'); res.put('description', 'partly cloudy'); res.put('icon', '03' + d);
        } else if (code == 3) {
            res.put('main', 'Clouds'); res.put('description', 'overcast'); res.put('icon', '04' + d);
        } else if (code == 45 || code == 48) {
            res.put('main', 'Fog'); res.put('description', 'fog'); res.put('icon', '50' + d);
        } else if (code >= 51 && code <= 57) {
            res.put('main', 'Drizzle'); res.put('description', 'drizzle'); res.put('icon', '09' + d);
        } else if (code >= 61 && code <= 65) {
            res.put('main', 'Rain'); res.put('description', 'rain'); res.put('icon', '10' + d);
        } else if (code == 66 || code == 67) {
            res.put('main', 'Rain'); res.put('description', 'freezing rain'); res.put('icon', '13' + d);
        } else if (code >= 71 && code <= 77) {
            res.put('main', 'Snow'); res.put('description', 'snow'); res.put('icon', '13' + d);
        } else if (code >= 80 && code <= 82) {
            res.put('main', 'Rain'); res.put('description', 'rain showers'); res.put('icon', '09' + d);
        } else if (code == 85 || code == 86) {
            res.put('main', 'Snow'); res.put('description', 'snow showers'); res.put('icon', '13' + d);
        } else if (code >= 95 && code <= 99) {
            res.put('main', 'Thunderstorm'); res.put('description', 'thunderstorm'); res.put('icon', '11' + d);
        } else {
            res.put('main', 'Unknown'); res.put('description', 'unknown'); res.put('icon', '01' + d);
        }
        return res;
    }

    @TestVisible
    private static HttpResponse makeCallout(String url) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(10000);
        return http.send(req);
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) return 0;
        if (val instanceof Decimal) return (Decimal) val;
        if (val instanceof Integer) return Decimal.valueOf((Integer) val);
        if (val instanceof Long) return Decimal.valueOf((Long) val);
        try { return Decimal.valueOf(String.valueOf(val)); } catch (Exception e) { return 0; }
    }

    private static Integer toInteger(Object val) {
        if (val == null) return 0;
        if (val instanceof Integer) return (Integer) val;
        try { return Integer.valueOf(String.valueOf(val)); } catch (Exception e) { return 0; }
    }

    private static Long toLong(Object val) {
        if (val == null) return null;
        if (val instanceof Long) return (Long) val;
        if (val instanceof Integer) return (Long) val;
        try { return Long.valueOf(String.valueOf(val)); } catch (Exception e) { return null; }
    }
}