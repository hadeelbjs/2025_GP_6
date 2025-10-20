const mongoose = require('mongoose');

const connectDatabase = async () => {
  try {
    const options = {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    };

    await mongoose.connect(process.env.MONGODB_URI, options);
    
    console.log('MongoDB Connected');
    console.log(`Database: ${mongoose.connection.name}`);

    // Connection Events
    mongoose.connection.on('error', (err) => {
      console.error('MongoDB Error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.warn('MongoDB Disconnected');
    });

    mongoose.connection.on('reconnected', () => {
      console.log('MongoDB Reconnected');
    });

  } catch (error) {
    console.error('MongoDB Connection Failed:', error.message);
    process.exit(1);
  }
};

module.exports = { connectDatabase };