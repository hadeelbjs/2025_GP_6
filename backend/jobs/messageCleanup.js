const cron = require('node-cron');
const Message = require('../models/Message');

function startMessageExpiryJob(io) {
  cron.schedule('*/20 * * * * *', async () => {
    try {
      const now = new Date();
      
      
      const expiredMessages = await Message.find({
        expiresAt: { $lte: now },
        isExpired: false,
      });
      
      if (expiredMessages.length === 0) {
        return;
      }
      
      
      for (const msg of expiredMessages) {
        try {
          const messageId = msg.messageId;
          const senderId = msg.senderId.toString();
          const recipientId = msg.recipientId.toString();
          
       
          
          const sentToSender = io.sendToUser(senderId, 'message:expired', {
            messageId: messageId,
            reason: 'duration_ended',
          });
          
          const sentToRecipient = io.sendToUser(recipientId, 'message:expired', {
            messageId: messageId,
            reason: 'duration_ended',
          });
          
        } catch (err) {
          console.error(`Failed to send expired event:`, err.message);
        }
      }
      
      const result = await Message.deleteMany({
        expiresAt: { $lte: now },
        isExpired: false,
      });
      
      
    } catch (err) {
      console.error('Message expiry job error:', err);
      console.error('   Stack:', err.stack);
    }
  });
  
}




module.exports = { 
  startMessageExpiryJob,

};