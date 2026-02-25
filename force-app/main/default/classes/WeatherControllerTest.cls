/**
 * @description Test class for WeatherController (Open-Meteo & Zippopotam.us).
 * Uses HttpCalloutMock to simulate API responses.
 *
 * @author Copilot
 * @since 2026-02-24
 */
@IsTest
private class WeatherControllerTest {

    // ─── Mock: Successful geocode (city) + weather ───
    private class SuccessCityMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('geocoding-api.open-meteo.com')) {
                res.setStatusCode(200);
                res.setBody('{"results":[{"id":5391959,"name":"San Francisco","latitude":37.77493,"longitude":-122.41942,"elevation":15.0,"feature_code":"PPLA2","country_code":"US","admin1_id":5332921,"admin2_id":5391997,"timezone":"America/Los_Angeles","population":864816,"country_id":6252001,"country":"United States","admin1":"California","admin2":"San Francisco"}]}');
            } else if (endpoint.contains('api.open-meteo.com/v1/forecast')) {
                res.setStatusCode(200);
                res.setBody(getMockWeather());
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":true,"reason":"Not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Successful geocode (zip) + weather ───
    private class SuccessZipMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('api.zippopotam.us')) {
                res.setStatusCode(200);
                res.setBody('{"post code": "94105", "country": "United States", "country abbreviation": "US", "places": [{"place name": "San Francisco", "longitude": "-122.3948", "state": "California", "state abbreviation": "CA", "latitude": "37.7864"}]}');
            } else if (endpoint.contains('api.open-meteo.com/v1/forecast')) {
                res.setStatusCode(200);
                res.setBody(getMockWeather());
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":true,"reason":"Not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Location not found (city) ───
    private class NotFoundCityMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('geocoding-api.open-meteo.com')) {
                res.setStatusCode(200);
                res.setBody('{"generationtime_ms":0.123}'); // No results array
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":true,"reason":"Not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Location not found (zip) ───
    private class NotFoundZipMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('api.zippopotam.us')) {
                res.setStatusCode(404);
                res.setBody('{}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":true,"reason":"Not found"}');
            }
            return res;
        }
    }

    // ─── Mock: Weather API returns error after successful geocode ───
    private class WeatherErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('geocoding-api.open-meteo.com')) {
                res.setStatusCode(200);
                res.setBody('{"results":[{"id":5391959,"name":"San Francisco","latitude":37.77493,"longitude":-122.41942,"country_code":"US"}]}');
            } else if (endpoint.contains('api.open-meteo.com/v1/forecast')) {
                res.setStatusCode(500);
                res.setBody('{"error":true,"reason":"Internal Server Error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // ─── Helper: Mock Weather JSON ───
    private static String getMockWeather() {
        return '{' +
            '"latitude": 37.7749,' +
            '"longitude": -122.4194,' +
            '"generationtime_ms": 0.123,' +
            '"utc_offset_seconds": -28800,' +
            '"timezone": "America/Los_Angeles",' +
            '"timezone_abbreviation": "PST",' +
            '"elevation": 15.0,' +
            '"current": {' +
                '"time": 1708790400,' +
                '"temperature_2m": 15.5,' +
                '"relative_humidity_2m": 75,' +
                '"apparent_temperature": 14.2,' +
                '"is_day": 1,' +
                '"weather_code": 3,' +
                '"cloud_cover": 100,' +
                '"surface_pressure": 1012.5,' +
                '"wind_speed_10m": 12.5' +
            '},' +
            '"daily": {' +
                '"time": [1708761600, 1708848000, 1708934400, 1709020800, 1709107200, 1709193600, 1709280000],' +
                '"weather_code": [3, 61, 0, 1, 2, 3, 45],' +
                '"temperature_2m_max": [18.5, 16.2, 19.1, 20.5, 21.0, 18.8, 17.5],' +
                '"temperature_2m_min": [10.2, 11.5, 9.8, 10.5, 11.2, 12.0, 10.8],' +
                '"sunrise": [1708786800, 1708873140, 1708959480, 1709045820, 1709132160, 1709218500, 1709304840],' +
                '"sunset": [1708826400, 1708912860, 1708999320, 1709085780, 1709172240, 1709258700, 1709345160],' +
                '"precipitation_probability_max": [10, 80, 0, 5, 10, 20, 5]' +
            '}' +
        '}';
    }

    // ─── Tests ───

    @IsTest
    static void testGetForecast_SuccessCity() {
        Test.setMock(HttpCalloutMock.class, new SuccessCityMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success to be true');
        System.assertEquals('San Francisco', result.locationName, 'Expected location name to match');
        System.assertEquals('US', result.country, 'Expected country to match');
        System.assertNotEquals(null, result.current, 'Expected current weather to be populated');
        System.assertEquals(15.5, result.current.temp, 'Expected current temp to match mock');
        System.assertEquals('Clouds', result.current.main, 'Expected weather code 3 to map to Clouds');
        System.assertEquals(7, result.daily.size(), 'Expected 7 days of forecast');
        System.assertEquals(18.5, result.daily[0].tempHigh, 'Expected daily high to match mock');
    }

    @IsTest
    static void testGetForecast_SuccessZip() {
        Test.setMock(HttpCalloutMock.class, new SuccessZipMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('94105');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success to be true');
        System.assertEquals('San Francisco', result.locationName, 'Expected location name to match');
        System.assertEquals('US', result.country, 'Expected country to match');
        System.assertNotEquals(null, result.current, 'Expected current weather to be populated');
    }

    @IsTest
    static void testGetForecast_BlankLocation() {
        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected success to be false');
        System.assertEquals('Please enter a location to search.', result.errorMessage, 'Expected blank location error message');
    }

    @IsTest
    static void testGetForecast_NotFoundCity() {
        Test.setMock(HttpCalloutMock.class, new NotFoundCityMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('FakeCity123');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected success to be false');
        System.assertEquals('Location not found. Try "City, Country" or a zip code.', result.errorMessage, 'Expected not found error message');
    }

    @IsTest
    static void testGetForecast_NotFoundZip() {
        Test.setMock(HttpCalloutMock.class, new NotFoundZipMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('00000');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected success to be false');
        System.assertEquals('Location not found. Try "City, Country" or a zip code.', result.errorMessage, 'Expected not found error message');
    }

    @IsTest
    static void testGetForecast_WeatherError() {
        Test.setMock(HttpCalloutMock.class, new WeatherErrorMock());

        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected success to be false');
        System.assert(result.errorMessage.contains('Unable to fetch weather data'), 'Expected weather fetch error message');
    }

    @IsTest
    static void testGetForecast_Exception() {
        // No mock set, will throw CalloutException
        Test.startTest();
        WeatherController.WeatherResult result = WeatherController.getForecast('San Francisco');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected success to be false');
        System.assert(result.errorMessage.contains('An error occurred'), 'Expected exception error message');
    }
}