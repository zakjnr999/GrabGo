const { Client } = require('@googlemaps/google-maps-services-js');

class RouteOptimizationService {
    constructor() {
        this.googleMapsClient = new Client({});
    }

    //optimize route for multiple deliveries
    async optimizeMultiDeliveryRoute(riderLocation, deliveries) {
        try {
            // build waypoints
            const waypoints = deliveries.map(delivery => ({
                location: `${delivery.destination.latitude},${delivery.destination.longitude}`,
                orderId: delivery.orderId
            }));

            // call Google Maps Directions API with waypoint optimization
            const response = await this.googleMapsClient.directions({
                params: {
                    origin: `${riderLocation.latitude},${riderLocation.longitude}`,
                    destination: waypoints[waypoints.length - 1].location,
                    waypoints: waypoints.slice(0, -1).map(w => w.location),
                    optimize: true,
                    mode: 'driving',
                    key: process.env.GOOGLE_MAPS_API_KEY
                }
            });

            if (response.data.routes.length === 0) {
                throw new Error('No route found');
            }

            const route = response.data.routes[0];

            // get optimized order
            const optimizedOrder = route.waypoint_order || [];
            const optimizedDeliveries = optimizedOrder.map(index => deliveries[index]);

            // Add the last delivery
            optimizedDeliveries.push(deliveries[deliveries.length - 1]);

            return {
                optimizedDeliveries,
                totalDistance: route.legs.reduce((sum, leg) => sum + leg.distance.value, 0),
                totalDuration: route.legs.reduce((sum, leg) => sum + leg.distance.value, 0),
                polyline: route.overview_polyline.points
            };

        } catch (error) {
            console.error('Error optimizing route:', error);
            // return original order on error
            return {
                optimizedDeliveries: deliveries,
                totalDistance: 0,
                totalDuration: 0,
                polyline: null
            };
        }
    }
}

module.exports = new RouteOptimizationService();