/**
 * @description Next-Gen Weather Forecast LWC Controller.
 * Fetches weather data via imperative Apex call and renders
 * current conditions + multi-day forecast with glassmorphism UI.
 *
 * @author Copilot
 * @since 2026-02-24
 */
import { LightningElement, track } from 'lwc';
import getForecast from '@salesforce/apex/WeatherController.getForecast';

const ICON_BASE_URL = 'https://openweathermap.org/img/wn/';
const ICON_SUFFIX = '@2x.png';

export default class WeatherForecast extends LightningElement {
    @track searchQuery = '';
    @track weatherData = null;
    @track isLoading = false;
    @track errorMessage = '';

    // ─── Computed Properties ─────────────────────────

    get hasWeatherData() {
        return this.weatherData && this.weatherData.current && !this.isLoading && !this.errorMessage;
    }

    get hasForecast() {
        return this.weatherData && this.weatherData.daily && this.weatherData.daily.length > 0;
    }

    get showContent() {
        return this.hasWeatherData || this.isLoading || this.errorMessage;
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

    get currentTempRounded() {
        if (!this.weatherData?.current?.temp) return '--';
        return Math.round(this.weatherData.current.temp);
    }

    get feelsLikeRounded() {
        if (!this.weatherData?.current?.feelsLike) return '--';
        return Math.round(this.weatherData.current.feelsLike);
    }

    get tempMaxRounded() {
        if (!this.weatherData?.current?.tempMax) return '--';
        return Math.round(this.weatherData.current.tempMax);
    }

    get tempMinRounded() {
        if (!this.weatherData?.current?.tempMin) return '--';
        return Math.round(this.weatherData.current.tempMin);
    }

    get currentIconUrl() {
        if (!this.weatherData?.current?.icon) return '';
        return ICON_BASE_URL + this.weatherData.current.icon + ICON_SUFFIX;
    }

    get windDisplay() {
        if (!this.weatherData?.current?.windSpeed) return '-- m/s';
        return `${this.weatherData.current.windSpeed} m/s`;
    }

    get visibilityDisplay() {
        if (!this.weatherData?.current?.visibility) return '--';
        const km = (this.weatherData.current.visibility / 1000).toFixed(1);
        return `${km} km`;
    }

    get sunriseTime() {
        if (!this.weatherData?.current?.sunrise) return '--';
        return this._formatUnixTime(this.weatherData.current.sunrise);
    }

    get sunsetTime() {
        if (!this.weatherData?.current?.sunset) return '--';
        return this._formatUnixTime(this.weatherData.current.sunset);
    }

    // ─── Event Handlers ──────────────────────────────

    handleSearchInput(event) {
        this.searchQuery = event.detail?.value ?? event.target?.value ?? '';
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleSearch() {
        const query = this.searchQuery?.trim();
        if (!query) return;

        this.isLoading = true;
        this.errorMessage = '';
        this.weatherData = null;

        getForecast({ location: query })
            .then((result) => {
                if (result.success) {
                    // Decorate daily forecast with icon URLs
                    if (result.daily) {
                        result.daily = result.daily.map((day) => ({
                            ...day,
                            iconUrl: day.icon ? ICON_BASE_URL + day.icon + ICON_SUFFIX : ''
                        }));
                    }
                    this.weatherData = result;
                    this.errorMessage = '';
                } else {
                    this.errorMessage = result.errorMessage || 'Something went wrong.';
                    this.weatherData = null;
                }
            })
            .catch((error) => {
                this.errorMessage = error?.body?.message || 'Failed to fetch weather data.';
                this.weatherData = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Private Helpers ─────────────────────────────

    _formatUnixTime(timestamp) {
        if (!timestamp) return '--';
        const date = new Date(timestamp * 1000);
        const hours = date.getHours().toString().padStart(2, '0');
        const minutes = date.getMinutes().toString().padStart(2, '0');
        return `${hours}:${minutes}`;
    }
}
