const cron = require('node-cron');
const Message = require('../models/Message');

function startMessageExpiryJob(io) {
  cron.schedule('*/20 * * * * *', async () => {
    try {
      const now = new Date();
      
      console.log(`\n⏰ [${now.toISOString()}] Checking for expired messages...`);
      
      const expiredMessages = await Message.find({
        expiresAt: { $lte: now },
        isExpired: false,
      });
      
      if (expiredMessages.length === 0) {
        return;
      }
      
      console.log(`   ⏱️  Found ${expiredMessages.length} expired messages`);
      
      for (const msg of expiredMessages) {
        try {
          const messageId = msg.messageId;
          const senderId = msg.senderId.toString();
          const recipientId = msg.recipientId.toString();
          
          console.log(`   📨 Processing: ${messageId}`);
       
          
          const sentToSender = io.sendToUser(senderId, 'message:expired', {
            messageId: messageId,
            reason: 'duration_ended',
          });
          console.log(`      ${sentToSender ? '✅' : '❌'} Sent to sender`);
          
          const sentToRecipient = io.sendToUser(recipientId, 'message:expired', {
            messageId: messageId,
            reason: 'duration_ended',
          });
          console.log(`      ${sentToRecipient ? '✅' : '❌'} Sent to recipient`);
          
        } catch (err) {
          console.error(`   ❌ Failed to send expired event:`, err.message);
        }
      }
      
      const result = await Message.deleteMany({
        expiresAt: { $lte: now },
        isExpired: false,
      });
      
      console.log(`   🗑️  Deleted ${result.deletedCount} messages from MongoDB\n`);
      
    } catch (err) {
      console.error('❌ Message expiry job error:', err);
      console.error('   Stack:', err.stack);
    }
  });
  
  console.log('⏱️  Message expiry job started (runs every 30 seconds)');
}



function startDeliveredMessagesCleanup() {
  cron.schedule('0 3 * * 0', async () => {
    try {
      const oneWeekAgo = new Date();
      oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
      
      const result = await Message.deleteMany({
        status: { $in: ['delivered', 'verified'] },
        deliveredAt: { $lt: oneWeekAgo },
      });
      
      console.log(`🧹 Weekly cleanup: Deleted ${result.deletedCount} old delivered messages`);
      
    } catch (err) {
      console.error('❌ Delivered messages cleanup error:', err);
    }
  });
  
  console.log('🧹 Delivered messages cleanup started (runs weekly)');
}

module.exports = { 
  startMessageExpiryJob,
  startDeliveredMessagesCleanup, 
};