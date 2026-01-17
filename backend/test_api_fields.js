const axios = require('axios');

async function testApi() {
    try {
        const baseUrl = 'http://localhost:5000/api'; // Adjust port if needed
        console.log('Testing /foods/popular...');
        const res = await axios.get(`${baseUrl}/foods/popular`);
        if (res.data.success && res.data.data.length > 0) {
            const item = res.data.data[0];
            console.log('Item Name:', item.name);
            console.log('Food Image field:', item.food_image);
            console.log('Image field:', item.image);
            console.log('Restaurant Name field:', item.restaurant?.restaurant_name);
            console.log('Restaurant Image field:', item.restaurant?.image);
        } else {
            console.log('No data returned or success=false');
        }
    } catch (err) {
        console.error('Connection error (is server running?):', err.message);
    }
}

testApi();
