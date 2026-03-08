const { Client } = require('@googlemaps/google-maps-services-js');

const googleMapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

class DirectionsService {
    isConfigured() {
        return Boolean(GOOGLE_MAPS_API_KEY);
    }

    /**
     * Fetch a routed path from Google Directions.
     * Returns null when no route exists.
     */
    async getRoute({
        originLat,
        originLng,
        destinationLat,
        destinationLng,
        mode = 'driving',
    }) {
        if (!this.isConfigured()) {
            throw new Error('GOOGLE_MAPS_API_KEY is not configured');
        }

        const response = await googleMapsClient.directions({
            params: {
                origin: `${originLat},${originLng}`,
                destination: `${destinationLat},${destinationLng}`,
                mode,
                key: GOOGLE_MAPS_API_KEY,
            },
        });

        const route = response?.data?.routes?.[0];
        const leg = route?.legs?.[0];

        if (
            !route ||
            !Number.isFinite(leg?.distance?.value) ||
            !Number.isFinite(leg?.duration?.value) ||
            !route?.overview_polyline?.points
        ) {
            return null;
        }

        return {
            polyline: route.overview_polyline.points,
            distance: leg.distance.value,
            duration: leg.duration.value,
        };
    }
}

module.exports = new DirectionsService();
