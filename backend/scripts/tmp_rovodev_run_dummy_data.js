// Quick script to run the dummy data creation
const { createDummyData } = require('./tmp_rovodev_create_dummy_food_data');

createDummyData().catch(console.error);