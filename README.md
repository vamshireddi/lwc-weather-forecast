# Next-Gen Weather Forecast LWC

A **Next-Gen Weather Forecast** application built on the Salesforce Platform with a glassmorphism/Bento Box UI. This component provides a rich, interactive weather experience directly within Salesforce.

## ✨ Features

- **No API Key Required**: Powered by the free [Open-Meteo API](https://open-meteo.com/) for weather data and [Zippopotam.us](https://api.zippopotam.us/) for US zip code resolution.
- **GPS Location (Use My Location)**: Instantly fetch weather for your current coordinates using browser geolocation.
- **Fahrenheit / Celsius Toggle**: Seamlessly switch between units without reloading data.
- **Dynamic Backgrounds (Bluish Tint Theme)**: The UI automatically shifts between beautiful shades of blue depending on the current weather (Sunny, Cloudy, Rainy, Snowy, Night).
- **24-Hour Forecast Slider**: A horizontally scrollable timeline showing temperature and conditions for the next 24 hours.
- **Daily Forecast Drill-down**: Click on any day in the 7-day forecast to view detailed metrics (Rain Chance, Wind, Low Temp) in the main hero section.
- **Recent Searches**: The search bar remembers your last 5 successful searches using local storage for quick access.
- **Smart Search**: Intelligently handles city names, "City, Country", and mixed strings like "McKinney 75070" by extracting the zip code automatically.

## 🏗 Architecture

| Layer | File | Purpose |
|---|---|---|
| Apex Controller | `WeatherController.cls` | REST callouts to Open-Meteo (geocode + current + hourly + daily) and Zippopotamus |
| LWC Template | `weatherForecast.html` | Bento-box layout with hero, chips, hourly slider, and forecast grid |
| LWC Controller | `weatherForecast.js` | Imperative Apex calls, reactive state, GPS handling, local storage, unit conversion |
| LWC Styles | `weatherForecast.css` | Glassmorphism theme, dynamic background classes, responsive grid |

## 🚀 Setup & Installation
<img width="1853" height="1081" alt="image" src="https://github.com/user-attachments/assets/978af40a-aeb8-4842-b79e-2d10b4339eb4" />

### 1. Deploy to Salesforce

Clone the repository and deploy the source code to your org:

```bash
# Authenticate to your org
sf org login web --alias myOrg

# Deploy the component and Apex classes
sf project deploy start -d force-app -o myOrg
```

### 2. Required Metadata (Included in Deployment)

The deployment automatically includes the necessary security settings to allow the component to function:

**Remote Site Settings** (Allows Apex to make HTTP callouts):
- `OpenMeteoAPI` (`https://api.open-meteo.com`)
- `OpenMeteoGeocoding` (`https://geocoding-api.open-meteo.com`)
- `Zippopotamus` (`https://api.zippopotam.us`)

**CSP Trusted Sites** (Allows LWC to render external images):
- `OpenWeatherMapIcons` (`https://openweathermap.org`) - Used exclusively for rendering weather condition icons.

### 3. Add to a Lightning Page

1. Go to **Setup > Tabs > Lightning Component Tabs > New**
2. Select **"weatherForecast"**
3. Add the tab to your app navigation
4. Or use **Lightning App Builder** to drag the component onto any Home, Record, or App page.

## 📡 API Details

This app uses the following free APIs (No authentication required):

| Endpoint | Purpose |
|---|---|
| `https://geocoding-api.open-meteo.com/v1/search` | Geocode city names to lat/lon |
| `https://api.zippopotam.us/us/{zip}` | Geocode US zip codes to lat/lon |
| `https://api.open-meteo.com/v1/forecast` | Fetch current, hourly, and daily weather data |
| `https://openweathermap.org/img/wn/` | Fetch weather condition icons |

## 📄 License

MIT
