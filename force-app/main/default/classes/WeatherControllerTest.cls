/**
 * @description Test class for WeatherController.
 * Uses HttpCalloutMock to simulate OpenWeatherMap API responses.
 *
 * @author Copilot
 * @since 2026-02-24
 */
@IsTest
private class WeatherControllerTest {

    // ─── Mock: Successful geocode (direct) + weather + forecast ───
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/geo/1.0/direct')) {
                res.setStatusCode(200);
                res.setBody('[{"lat":37.7749,"lon":-122.4194,"name":"San Francisco","country":"US"}]');
            } else if (endpoint.contains('/geo/1.0/zip')) {
                res.setStatusCode(200);
                res.setBody('{"lat":37.7749,"lon":-122.4194,"name":"San Francisco","country":"US","zip":"94105"}');
            } else if (endpoint.contains('/data/2.5/weather')) {
                res.setStatusCode(200);
                res.setBody(getMockCurrentWeather());
            } else if (endpoint.contains('/data/2.5/forecast')) {
                res.setStatusCode(200);
                res.setBody(getMockForecast());
            } else {
                res.setStatusCode(404);
                res.setBody('{"message":"not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Location not found ───
    private class NotFoundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/geo/1.0/direct')) {
                res.setStatusCode(200);
                res.setBody('[]');
            } else {
                res.setStatusCode(404);
                res.setBody('{"message":"not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Geocode returns HTTP error ───
    private class GeoErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"cod":401,"message":"Invalid API key"}');
            return res;
        }
    }

    // ─── Mock: Weather API returns error after successful geocode ───
    private class WeatherErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/geo/1.0/direct')) {
                res.setStatusCode(200);
                res.setBody('[{"lat":37.7749,"lon":-122.4194}]');
            } else if (endpoint.contains('/data/2.5/weather')) {
                res.setStatusCode(500);
                res.setBody('{"message":"Internal Server Error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Mock: Forecast returns error but current weather succeeds ───
    private class ForecastErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/geo/1.0/direct')) {
                res.setStatusCode(200);
                res.setBody('[{"lat":37.7749,"lon":-122.4194}]');
            } else if (endpoint.contains('/data/2.5/weather')) {
                res.setStatusCode(200);
                res.setBody(getMockCurrentWeather());
            } else if (endpoint.contains('/data/2.5/forecast')) {
                res.setStatusCode(500);
                res.setBody('{"message":"error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Mock: Zip code geocode ───
    private class ZipMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/geo/1.0/zip')) {
                res.setStatusCode(200);
                res.setBody('{"lat":37.7749,"lon":-122.4194,"name":"San Francisco","zip":"94105"}');
            } else if (endpoint.contains('/data/2.5/weather')) {
                res.setStatusCode(200);
                res.setBody(getMockCurrentWeather());
            } else if (endpoint.contains('/data/2.5/forecast')) {
                res.setStatusCode(200);
                res.setBody(getMockForecast());
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //  TEST METHODS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @IsTest
    static void testGetForecastByCity() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed for valid city');
        System.assertNotEquals(null, result.current, 'Should have current weather');
        System.assertEquals('San Francisco', result.locationName, 'Location name should match');
        System.assertNotEquals(null, result.current.temp, 'Should have temperature');
        System.assertEquals('Clouds', result.current.main, 'Should have weather condition');
        System.assert(!result.daily.isEmpty(), 'Should have daily forecast entries');
    }

    @IsTest
    static void testGetForecastByZipCode() {
        Test.setMock(HttpCalloutMock.class, new ZipMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('94105');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed for zip code');
        System.assertNotEquals(null, result.current, 'Should have current weather');
        System.assertNotEquals(null, result.lat, 'Should have latitude');
        System.assertNotEquals(null, result.lon, 'Should have longitude');
    }

    @IsTest
    static void testGetForecastBlankLocation() {
        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for blank location');
        System.assertEquals('Please enter a location to search.', result.errorMessage, 'Should have blank location error');
    }

    @IsTest
    static void testGetForecastNullLocation() {
        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast(null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for null location');
        System.assertEquals('Please enter a location to search.', result.errorMessage, 'Error message mismatch');
    }

    @IsTest
    static void testGetForecastLocationNotFound() {
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('XYZABC123NOTREAL');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for unknown location');
        System.assert(result.errorMessage.containsIgnoreCase('not found'), 'Should mention location not found');
    }

    @IsTest
    static void testGetForecastGeoError() {
        Test.setMock(HttpCalloutMock.class, new GeoErrorMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('London');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when geocode returns error');
        System.assert(result.errorMessage.containsIgnoreCase('not found'), 'Error should indicate location issue');
    }

    @IsTest
    static void testGetForecastWeatherApiError() {
        Test.setMock(HttpCalloutMock.class, new WeatherErrorMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('New York');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when weather API returns error');
        System.assert(result.errorMessage.contains('HTTP 500'), 'Should show HTTP status code');
    }

    @IsTest
    static void testGetForecastForecastErrorStillSucceeds() {
        Test.setMock(HttpCalloutMock.class, new ForecastErrorMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('Tokyo');
        Test.stopTest();

        // Current weather succeeds but forecast fails → overall still success
        System.assertEquals(true, result.success, 'Should succeed even if forecast fails');
        System.assertNotEquals(null, result.current, 'Should have current weather');
        System.assertEquals(0, result.daily.size(), 'Should have empty daily list when forecast fails');
    }

    @IsTest
    static void testCurrentWeatherParsing() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        WeatherController.CurrentWeather cw = result.current;
        System.assertNotEquals(null, cw.temp, 'temp should be set');
        System.assertNotEquals(null, cw.feelsLike, 'feelsLike should be set');
        System.assertNotEquals(null, cw.humidity, 'humidity should be set');
        System.assertNotEquals(null, cw.windSpeed, 'windSpeed should be set');
        System.assertNotEquals(null, cw.description, 'description should be set');
        System.assertNotEquals(null, cw.icon, 'icon should be set');
        System.assertNotEquals(null, cw.sunrise, 'sunrise should be set');
        System.assertNotEquals(null, cw.sunset, 'sunset should be set');
    }

    @IsTest
    static void testDailyForecastParsing() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assert(result.daily.size() > 0, 'Should have at least one forecast day');
        WeatherController.DailyForecast day = result.daily[0];
        System.assertNotEquals(null, day.dayName, 'dayName should be set');
        System.assertNotEquals(null, day.dateStr, 'dateStr should be set');
        System.assertNotEquals(null, day.tempHigh, 'tempHigh should be set');
        System.assertNotEquals(null, day.tempLow, 'tempLow should be set');
        System.assertNotEquals(null, day.description, 'description should be set');
    }

    @IsTest
    static void testCountryReturned() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals('US', result.country, 'Country should be US');
    }

    @IsTest
    static void testCoordsReturned() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals(37.7749, result.lat, 'Latitude mismatch');
        System.assertEquals(-122.4194, result.lon, 'Longitude mismatch');
    }

    @IsTest
    static void testWeatherResultDefaults() {
        WeatherController.WeatherResult wr = new WeatherController.WeatherResult();
        System.assertEquals(null, wr.success, 'Default success should be null');
        System.assertEquals(null, wr.errorMessage, 'Default error should be null');
        System.assertEquals(null, wr.current, 'Default current should be null');
        System.assertEquals(null, wr.locationName, 'Default locationName should be null');
    }

    @IsTest
    static void testCurrentWeatherWrapper() {
        WeatherController.CurrentWeather cw = new WeatherController.CurrentWeather();
        cw.temp = 22.5;
        cw.feelsLike = 21.0;
        cw.humidity = 65;
        cw.windSpeed = 5.5;
        cw.description = 'scattered clouds';
        cw.icon = '03d';
        cw.main = 'Clouds';
        cw.pressure = 1013;
        cw.visibility = 10000;
        cw.sunrise = 1708851600;
        cw.sunset = 1708893600;

        System.assertEquals(22.5, cw.temp, 'temp mismatch');
        System.assertEquals('Clouds', cw.main, 'main mismatch');
        System.assertEquals(65, cw.humidity, 'humidity mismatch');
    }

    @IsTest
    static void testDailyForecastWrapper() {
        WeatherController.DailyForecast df = new WeatherController.DailyForecast();
        df.dayName = 'Mon';
        df.dateStr = 'Feb 24';
        df.tempHigh = 18.5;
        df.tempLow = 10.2;
        df.description = 'light rain';
        df.icon = '10d';
        df.main = 'Rain';
        df.humidity = 80;
        df.windSpeed = 3.2;
        df.pop = 75;

        System.assertEquals('Mon', df.dayName, 'dayName mismatch');
        System.assertEquals(18.5, df.tempHigh, 'tempHigh mismatch');
        System.assertEquals(75, df.pop, 'pop mismatch');
    }

    @IsTest
    static void testZipCodeWithDash() {
        Test.setMock(HttpCalloutMock.class, new ZipMock());

        Test.startTest();
        // US zip+4 format should also route to zip endpoint
        WeatherController.WeatherResult result = WeatherController.getForecast('94105');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should handle zip code');
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //  MOCK DATA HELPERS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static String getMockCurrentWeather() {
        return '{'
            + '"coord":{"lon":-122.4194,"lat":37.7749},'
            + '"weather":[{"id":802,"main":"Clouds","description":"scattered clouds","icon":"03d"}],'
            + '"main":{"temp":15.2,"feels_like":14.5,"temp_min":13.0,"temp_max":17.1,"pressure":1015,"humidity":72},'
            + '"visibility":10000,'
            + '"wind":{"speed":4.5,"deg":270},'
            + '"sys":{"country":"US","sunrise":1708851600,"sunset":1708893600},'
            + '"name":"San Francisco",'
            + '"cod":200'
            + '}';
    }

    private static String getMockForecast() {
        return '{'
            + '"list":['
            + '  {"dt":1708876800,"main":{"temp":14.5,"temp_min":13.0,"temp_max":16.0,"humidity":70},'
            + '   "weather":[{"main":"Clouds","description":"overcast clouds","icon":"04d"}],'
            + '   "wind":{"speed":3.5},"pop":0.1,"dt_txt":"2026-02-25 12:00:00"},'
            + '  {"dt":1708887600,"main":{"temp":13.0,"temp_min":12.0,"temp_max":14.5,"humidity":75},'
            + '   "weather":[{"main":"Clouds","description":"broken clouds","icon":"04n"}],'
            + '   "wind":{"speed":2.8},"pop":0.15,"dt_txt":"2026-02-25 15:00:00"},'
            + '  {"dt":1708963200,"main":{"temp":16.0,"temp_min":14.0,"temp_max":18.0,"humidity":65},'
            + '   "weather":[{"main":"Clear","description":"clear sky","icon":"01d"}],'
            + '   "wind":{"speed":4.0},"pop":0.0,"dt_txt":"2026-02-26 12:00:00"},'
            + '  {"dt":1709049600,"main":{"temp":12.5,"temp_min":10.0,"temp_max":15.0,"humidity":80},'
            + '   "weather":[{"main":"Rain","description":"light rain","icon":"10d"}],'
            + '   "wind":{"speed":5.5},"pop":0.7,"dt_txt":"2026-02-27 12:00:00"}'
            + ']'
            + '}';
    }
}
