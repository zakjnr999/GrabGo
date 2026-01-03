require('dotenv').config();
const mongoose = require('mongoose');
const GroceryItem = require('../models/GroceryItem');

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo')
    .then(async () => {
        const item = await GroceryItem.findOne();
        if (item) {
            console.log(`ID: ${item._id}`);
            console.log(`Name: ${item.name}`);
            console.log(`Price: ${item.price}`);
        } else {
            console.log('No grocery items found');
        }
        process.exit(0);
    })
    .catch(err => {
        console.error('Error:', err.message);
        process.exit(1);
    });
