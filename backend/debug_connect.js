const fs = require('fs');
const log = (msg) => fs.appendFileSync('debug_output.txt', msg + '\n');

log('Starting script');
try {
    const mongoose = require('mongoose');
    const path = require('path');
    const dotenv = require('dotenv');

    log('Modules loaded');

    const result = dotenv.config({ path: path.resolve(__dirname, '.env') });
    log(`Dotenv parsed: ${JSON.stringify(result.parsed)}`);

    if (result.error) log(`Dotenv Error: ${result.error}`);

    const uri = process.env.MONGODB_URI;
    log(`URI: ${uri}`);

    if (!uri) {
        log('No URI found');
        process.exit(1);
    }

    mongoose.connect(uri)
        .then(() => {
            log('Connected successfully');
            return mongoose.connection.close();
        })
        .then(() => {
            log('Connection closed');
            process.exit(0);
        })
        .catch(err => {
            log(`Connection error: ${err}`);
            process.exit(1);
        });

} catch (e) {
    log(`Global error: ${e}`);
}
