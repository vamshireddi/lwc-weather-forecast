# LWC Weather Forecast

A **Next-Gen Weather Forecast** application built on the Salesforce Platform with a glassmorphism/Bento Box UI.

## Features

- **City or Zip Search** - Search by city name, "City, Country", or US zip code
- **Current Conditions** - Temperature, feels-like, humidity, wind, visibility, pressure, sunrise/sunset
- **Multi-Day Forecast** - Horizontal scrollable cards with high/low temps, precipitation probability, and weather icons
- **Glassmorphism Design** - Frosted glass cards, gradient backgrounds, smooth animations
- **Skeleton Loader** - Premium loading states instead of generic spinners
- **Error Handling** - Location not found, API errors, blank input validation
- **Responsive** - Scales from mobile to full desktop via CSS Grid

## Architecture

| Layer | File | Purpose |
|---|---|---|
| Apex Controller | `WeatherController.cls` | REST callouts to OpenWeatherMap (geocode + current + forecast) |
| Apex Tests | `WeatherControllerTest.cls` | 16 tests with HttpCalloutMock for all API scenarios |
| LWC Template | `weatherForecast.html` | Bento-box layout with hero, chips, forecast grid |
| LWC Controller | `weatherForecast.js` | Imperative Apex calls, reactive state, computed properties |
| LWC Styles | `weatherForecast.css` | Glassmorphism theme matching lwc-calculator aesthetic |
| Jest Tests | `weatherForecast.test.js` | 22 Jest tests for rendering, search, error states |

## Setup

### 1. Get an OpenWeatherMap API Key

1. Sign up at [openweathermap.org](https://openweathermap.org/api)
2. Get a free API key (the free tier supports current weather + 5-day forecast)
3. Open `WeatherController.cls` and replace `YOUR_API_KEY_HERE` with your key

### 2. Create a Remote Site Setting

In your Salesforce org:
1. Go to **Setup > Security > Remote Site Settings**
2. Click **New Remote Site**
3. Set:
   - **Name**: `OpenWeatherMap`
   - **URL**: `https://api.openweathermap.org`
   - **Active**: checked
4. Save

### 3. Deploy to Salesforce

```bash
git clone https://github.com/vamshireddi/lwc-weather-forecast.git
cd lwc-weather-forecast
npm install

# Authenticate to your org
sf org login web --alias myOrg

# Deploy
sf deploy metadata --source-dir force-app --target-org myOrg --wait 20

# Run Apex tests
sf apex run test --tests WeatherControllerTest --result-format human --wait 20
```

### 4. Add to a Lightning Page

1. Go to **Setup > Tabs > Lightning Component Tabs > New**
2. Select **"Next-Gen Weather Forecast"**
3. Add the tab to your app navigation
4. Or use **Lightning App Builder** to drag the component onto any page

### 5. Run Jest Tests (local)

```bash
npm run test:unit
```

## API Details

This app uses the [OpenWeatherMap API](https://openweathermap.org/api) free tier:

| Endpoint | Purpose |
|---|---|
| `/geo/1.0/direct` | Geocode city names to lat/lon |
| `/geo/1.0/zip` | Geocode zip codes to lat/lon |
| `/data/2.5/weather` | Current weather conditions |
| `/data/2.5/forecast` | 5-day/3-hour forecast (aggregated to daily) |

## License

MIT
