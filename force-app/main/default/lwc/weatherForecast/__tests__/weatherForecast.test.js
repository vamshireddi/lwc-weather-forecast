/**
 * @description Jest tests for the weatherForecast LWC component.
 * Tests rendering, search interactions, Apex integration (mocked),
 * error handling, and skeleton loader states.
 *
 * @author Copilot
 * @since 2026-02-24
 */
import { createElement } from 'lwc';
import WeatherForecast from 'c/weatherForecast';
import getForecast from '@salesforce/apex/WeatherController.getForecast';

// Mock Apex
jest.mock(
    '@salesforce/apex/WeatherController.getForecast',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// ─── Mock Data ───────────────────────────────────

const MOCK_SUCCESS = {
    success: true,
    locationName: 'San Francisco',
    country: 'US',
    lat: 37.77,
    lon: -122.42,
    current: {
        temp: 15.2,
        feelsLike: 14.5,
        tempMin: 13.0,
        tempMax: 17.1,
        humidity: 72,
        windSpeed: 4.5,
        description: 'scattered clouds',
        icon: '03d',
        main: 'Clouds',
        pressure: 1015,
        visibility: 10000,
        sunrise: 1708851600,
        sunset: 1708893600
    },
    daily: [
        {
            dayName: 'Tue',
            dateStr: 'Feb 25',
            tempHigh: 16.0,
            tempLow: 13.0,
            description: 'overcast clouds',
            icon: '04d',
            main: 'Clouds',
            humidity: 70,
            windSpeed: 3.5,
            pop: 10
        },
        {
            dayName: 'Wed',
            dateStr: 'Feb 26',
            tempHigh: 18.0,
            tempLow: 14.0,
            description: 'clear sky',
            icon: '01d',
            main: 'Clear',
            humidity: 65,
            windSpeed: 4.0,
            pop: 0
        }
    ]
};

const MOCK_ERROR = {
    success: false,
    errorMessage: 'Location not found. Try "City, Country" or a zip code.'
};

// ─── Test Helpers ────────────────────────────────

function createComponent() {
    const element = createElement('c-weather-forecast', { is: WeatherForecast });
    document.body.appendChild(element);
    return element;
}

function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}

/**
 * Helper: set the search query and click the search button,
 * then flush enough microtask cycles for Apex + DOM re-render.
 */
async function searchAndWait(element, query) {
    const input = element.shadowRoot.querySelector('lightning-input');
    // Dispatch change event with detail.value (how lightning-input works)
    input.dispatchEvent(new CustomEvent('change', { detail: { value: query } }));
    await flushPromises();

    // Click search
    element.shadowRoot.querySelector('.search-btn').click();

    // Flush: 1) Apex promise resolution, 2) reactive re-render
    await flushPromises();
    await flushPromises();
}

// ─── Teardown ────────────────────────────────────

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  TEST SUITE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

describe('c-weather-forecast', () => {
    // ─── Rendering ───────────────────────────────

    it('renders the search bar on initial load', () => {
        const element = createComponent();
        const searchInput = element.shadowRoot.querySelector('lightning-input');
        expect(searchInput).not.toBeNull();
    });

    it('renders the search button', () => {
        const element = createComponent();
        const btn = element.shadowRoot.querySelector('.search-btn');
        expect(btn).not.toBeNull();
    });

    it('displays welcome state initially', () => {
        const element = createComponent();
        const welcome = element.shadowRoot.querySelector('.welcome-container');
        expect(welcome).not.toBeNull();
    });

    it('does not show hero section initially', () => {
        const element = createComponent();
        const hero = element.shadowRoot.querySelector('.hero-section');
        expect(hero).toBeNull();
    });

    // ─── Search Interaction ──────────────────────

    it('updates searchQuery on input change', async () => {
        const element = createComponent();
        const input = element.shadowRoot.querySelector('lightning-input');

        input.dispatchEvent(new CustomEvent('change', { detail: { value: 'London' } }));
        await flushPromises();
        expect(input).not.toBeNull();
    });

    it('calls getForecast on search button click', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'San Francisco');

        expect(getForecast).toHaveBeenCalled();
    });

    it('calls getForecast on Enter key press', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        const input = element.shadowRoot.querySelector('lightning-input');
        input.dispatchEvent(new CustomEvent('change', { detail: { value: 'Tokyo' } }));
        await flushPromises();

        input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter' }));
        await flushPromises();
        await flushPromises();

        expect(getForecast).toHaveBeenCalled();
    });

    it('does not call getForecast if search is empty', async () => {
        const element = createComponent();

        const btn = element.shadowRoot.querySelector('.search-btn');
        btn.click();

        await flushPromises();

        expect(getForecast).not.toHaveBeenCalled();
    });

    // ─── Successful Response ─────────────────────

    it('renders hero section after successful search', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'San Francisco');

        const hero = element.shadowRoot.querySelector('.hero-section');
        expect(hero).not.toBeNull();
    });

    it('displays location name and country', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const locName = element.shadowRoot.querySelector('.location-name');
        expect(locName.textContent).toBe('San Francisco, US');
    });

    it('displays current temperature', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const temp = element.shadowRoot.querySelector('.hero-temp');
        expect(temp.textContent).toBe('15');
    });

    it('displays weather description', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const desc = element.shadowRoot.querySelector('.hero-description');
        expect(desc.textContent).toBe('scattered clouds');
    });

    it('renders forecast cards', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const cards = element.shadowRoot.querySelectorAll('.forecast-card');
        expect(cards.length).toBe(2);
    });

    it('renders weather detail chips', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const chips = element.shadowRoot.querySelectorAll('.chip');
        expect(chips.length).toBe(4);
    });

    it('renders weather icon image', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const icon = element.shadowRoot.querySelector('.weather-icon-hero');
        expect(icon).not.toBeNull();
        expect(icon.src).toContain('03d@2x.png');
    });

    // ─── Error Handling ──────────────────────────

    it('displays error message when location not found', async () => {
        getForecast.mockResolvedValue(MOCK_ERROR);
        const element = createComponent();

        await searchAndWait(element, 'XXXNOTREAL');

        const errorEl = element.shadowRoot.querySelector('.error-text');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toContain('not found');
    });

    it('displays error on Apex exception', async () => {
        getForecast.mockRejectedValue({ body: { message: 'Server error' } });
        const element = createComponent();

        await searchAndWait(element, 'crash');

        const errorEl = element.shadowRoot.querySelector('.error-text');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toContain('Server error');
    });

    it('hides welcome state after a search', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const welcome = element.shadowRoot.querySelector('.welcome-container');
        expect(welcome).toBeNull();
    });

    // ─── Edge Cases ──────────────────────────────

    it('handles response with no daily forecast', async () => {
        const noDaily = { ...MOCK_SUCCESS, daily: [] };
        getForecast.mockResolvedValue(noDaily);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const cards = element.shadowRoot.querySelectorAll('.forecast-card');
        expect(cards.length).toBe(0);
    });

    it('shows forecast title when daily data exists', async () => {
        getForecast.mockResolvedValue(MOCK_SUCCESS);
        const element = createComponent();

        await searchAndWait(element, 'SF');

        const title = element.shadowRoot.querySelector('.forecast-title');
        expect(title).not.toBeNull();
        expect(title.textContent).toBe('Daily Forecast');
    });

    it('handles rejected promise with no body gracefully', async () => {
        getForecast.mockRejectedValue({});
        const element = createComponent();

        await searchAndWait(element, 'crash');

        const errorEl = element.shadowRoot.querySelector('.error-text');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toBe('Failed to fetch weather data.');
    });
});
