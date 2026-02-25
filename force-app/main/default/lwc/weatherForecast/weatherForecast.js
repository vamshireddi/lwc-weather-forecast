import { LightningElement, track } from 'lwc';
import getForecast from '@salesforce/apex/WeatherController.getForecast';
import getForecastByCoordinates from '@salesforce/apex/WeatherController.getForecastByCoordinates';

const ICON_BASE_URL = 'https://openweathermap.org/img/wn/';
const ICON_SUFFIX = '@2x.png';
const RECENT_SEARCHES_KEY = 'weather_recent_searches';

export default class WeatherForecast extends LightningElement {
    @track searchQuery = 'McKinney 75070';
    @track weatherData = null;
    @track isLoading = false;
    @track errorMessage = '';
    @track selectedDayIndex = null;
    
    @track isFahrenheit = true;
    @track recentSearches = [];
    @track showRecentSearches = false;
    @track dynamicBackgroundClass = 'bg-default';

    connectedCallback() {
        this.loadRecentSearches();
        this.handleSearch();
    }

    // ─── Computed Properties ─────────────────────────

    get isDaySelected() { return this.selectedDayIndex !== null; }
    get hasWeatherData() { return this.weatherData && this.weatherData.current && !this.isLoading && !this.errorMessage; }
    get hasForecast() { return this.weatherData && this.weatherData.daily && this.weatherData.daily.length > 0; }
    get hasHourly() { return this.weatherData && this.weatherData.hourly && this.weatherData.hourly.length > 0; }
    get showContent() { return this.hasWeatherData || this.isLoading || this.errorMessage; }
    get hasRecentSearches() { return this.recentSearches.length > 0; }

    get selectedDay() {
        if (this.selectedDayIndex !== null && this.weatherData && this.weatherData.daily) {
            return this.weatherData.daily[this.selectedDayIndex];
        }
        return null;
    }

    get locationDisplay() {
        if (!this.weatherData) return '';
        const name = this.weatherData.locationName || '';
        const country = this.weatherData.country || '';
        return country ? `${name}, ${country}` : name;
    }

    get coordsDisplay() {
        if (!this.weatherData || !this.weatherData.lat) return '';
        return `${Number(this.weatherData.lat).toFixed(2)}°N, ${Math.abs(Number(this.weatherData.lon)).toFixed(2)}°${Number(this.weatherData.lon) >= 0 ? 'E' : 'W'}`;
    }

    get tempUnit() { return this.isFahrenheit ? '°F' : '°C'; }
    get speedUnit() { return this.isFahrenheit ? 'mph' : 'm/s'; }
    get celsiusClass() { return this.isFahrenheit ? 'unit-label' : 'unit-label active'; }
    get fahrenheitClass() { return this.isFahrenheit ? 'unit-label active' : 'unit-label'; }

    get currentTempRounded() { return this._formatTemp(this.weatherData?.current?.temp); }
    get feelsLikeRounded() { return this._formatTemp(this.weatherData?.current?.feelsLike); }
    get tempMaxRounded() { return this._formatTemp(this.weatherData?.current?.tempMax); }
    get tempMinRounded() { return this._formatTemp(this.weatherData?.current?.tempMin); }
    
    get selectedDayHigh() { return this._formatTemp(this.selectedDay?.tempHigh); }
    get selectedDayLow() { return this._formatTemp(this.selectedDay?.tempLow); }

    get currentIconUrl() {
        if (!this.weatherData?.current?.icon) return '';
        return ICON_BASE_URL + this.weatherData.current.icon + ICON_SUFFIX;
    }

    get windDisplay() {
        return this._formatSpeed(this.weatherData?.current?.windSpeed);
    }
    
    get selectedDayWind() {
        return this._formatSpeed(this.selectedDay?.windSpeed);
    }

    get visibilityDisplay() {
        if (!this.weatherData?.current?.visibility) return '--';
        const km = (this.weatherData.current.visibility / 1000).toFixed(1);
        if (this.isFahrenheit) {
            return `${(km * 0.621371).toFixed(1)} mi`;
        }
        return `${km} km`;
    }

    get sunriseTime() { return this._formatUnixTime(this.weatherData?.current?.sunrise); }
    get sunsetTime() { return this._formatUnixTime(this.weatherData?.current?.sunset); }

    // ─── Event Handlers ──────────────────────────────

    handleSearchInput(event) {
        this.searchQuery = event.detail?.value ?? event.target?.value ?? '';
    }

    handleSearchFocus() {
        if (this.recentSearches.length > 0) {
            this.showRecentSearches = true;
        }
    }

    handleSearchBlur() {
        // Delay hiding to allow click event on dropdown to fire
        setTimeout(() => {
            this.showRecentSearches = false;
        }, 200);
    }

    handleRecentSearchClick(event) {
        const query = event.currentTarget.dataset.query;
        if (query) {
            this.searchQuery = query;
            this.showRecentSearches = false;
            this.handleSearch();
        }
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') {
            this.showRecentSearches = false;
            this.handleSearch();
        }
    }

    handleDayClick(event) {
        const index = event.currentTarget.dataset.index;
        if (index !== undefined) {
            this.selectedDayIndex = parseInt(index, 10);
        }
    }

    handleBackClick() {
        this.selectedDayIndex = null;
    }

    toggleUnit() {
        this.isFahrenheit = !this.isFahrenheit;
    }

    handleGetLocation() {
        if (navigator.geolocation) {
            this.isLoading = true;
            this.errorMessage = '';
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    this.fetchByCoords(lat, lon);
                },
                (error) => {
                    this.isLoading = false;
                    this.errorMessage = 'Unable to retrieve your location. Please check browser permissions.';
                }
            );
        } else {
            this.errorMessage = 'Geolocation is not supported by your browser.';
        }
    }

    handleSearch() {
        const query = this.searchQuery?.trim();
        if (!query) return;

        this.isLoading = true;
        this.errorMessage = '';
        this.weatherData = null;
        this.selectedDayIndex = null;

        getForecast({ location: query })
            .then((result) => this.processResult(result, query))
            .catch((error) => this.handleError(error));
    }

    fetchByCoords(lat, lon) {
        this.isLoading = true;
        this.errorMessage = '';
        this.weatherData = null;
        this.selectedDayIndex = null;

        getForecastByCoordinates({ lat: lat, lon: lon })
            .then((result) => {
                this.searchQuery = result.locationName || 'Current Location';
                this.processResult(result, this.searchQuery);
            })
            .catch((error) => this.handleError(error));
    }

    // ─── Private Helpers ─────────────────────────────

    processResult(result, query) {
        if (result.success) {
            const self = this;
            // Decorate daily forecast
            if (result.daily) {
                result.daily = result.daily.map((day) => ({
                    ...day,
                    iconUrl: day.icon ? ICON_BASE_URL + day.icon + ICON_SUFFIX : '',
                    get tempHighDisplay() { return self._formatTemp(day.tempHigh); },
                    get tempLowDisplay() { return self._formatTemp(day.tempLow); }
                }));
            }
            // Decorate hourly forecast
            if (result.hourly) {
                result.hourly = result.hourly.map((hour) => ({
                    ...hour,
                    iconUrl: hour.icon ? ICON_BASE_URL + hour.icon + ICON_SUFFIX : '',
                    get tempDisplay() { return self._formatTemp(hour.temp); }
                }));
            }
            
            this.weatherData = result;
            this.errorMessage = '';
            this.updateDynamicBackground();
            this.saveRecentSearch(query);
        } else {
            this.errorMessage = result.errorMessage || 'Something went wrong.';
            this.weatherData = null;
        }
        this.isLoading = false;
    }

    handleError(error) {
        this.errorMessage = error?.body?.message || 'Failed to fetch weather data.';
        this.weatherData = null;
        this.isLoading = false;
    }

    updateDynamicBackground() {
        if (!this.weatherData || !this.weatherData.current) {
            this.dynamicBackgroundClass = 'bg-default';
            return;
        }
        
        const code = this.weatherData.current.weatherCode;
        const isDay = this.weatherData.current.isDay;
        
        if (!isDay) {
            this.dynamicBackgroundClass = 'bg-night';
        } else if (code === 0 || code === 1) {
            this.dynamicBackgroundClass = 'bg-sunny';
        } else if (code === 2 || code === 3) {
            this.dynamicBackgroundClass = 'bg-cloudy';
        } else if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
            this.dynamicBackgroundClass = 'bg-rainy';
        } else if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
            this.dynamicBackgroundClass = 'bg-snowy';
        } else if (code >= 95 && code <= 99) {
            this.dynamicBackgroundClass = 'bg-stormy';
        } else {
            this.dynamicBackgroundClass = 'bg-default';
        }
    }

    loadRecentSearches() {
        try {
            const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
            if (stored) {
                this.recentSearches = JSON.parse(stored);
            }
        } catch (e) {
            console.error('Error loading recent searches', e);
        }
    }

    saveRecentSearch(query) {
        if (!query || query === 'Current Location') return;
        
        let searches = [...this.recentSearches];
        // Remove if exists to put it at the top
        searches = searches.filter(s => s.toLowerCase() !== query.toLowerCase());
        searches.unshift(query);
        // Keep only top 5
        if (searches.length > 5) {
            searches = searches.slice(0, 5);
        }
        
        this.recentSearches = searches;
        try {
            localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(searches));
        } catch (e) {
            console.error('Error saving recent searches', e);
        }
    }

    _formatTemp(celsius) {
        if (celsius === null || celsius === undefined) return '--';
        if (this.isFahrenheit) {
            return Math.round((celsius * 9/5) + 32);
        }
        return Math.round(celsius);
    }

    _formatSpeed(ms) {
        if (ms === null || ms === undefined) return '--';
        if (this.isFahrenheit) {
            return `${(ms * 2.23694).toFixed(1)} mph`;
        }
        return `${ms} m/s`;
    }

    _formatUnixTime(timestamp) {
        if (!timestamp) return '--';
        const date = new Date(timestamp * 1000);
        let hours = date.getHours();
        const minutes = date.getMinutes().toString().padStart(2, '0');
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12; // the hour '0' should be '12'
        return `${hours}:${minutes} ${ampm}`;
    }
}