const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.resolve(__dirname, '../groww-expense-firebase-adminsdk-fbsvc-5909ce3f5d.json');
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

function base64UrlEncode(str) {
  return Buffer.from(str).toString('base64url');
}

async function getGoogleAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const signatureInput = `${encodedHeader}.${encodedClaimSet}`;

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signatureInput);
  signer.end();
  const signature = signer.sign(serviceAccount.private_key, 'base64url');

  const jwt = `${signatureInput}.${signature}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Google OAuth2 Error: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

async function sendPushNotification({ token, title, body, data = {}, channelId = 'general_alerts_channel' }) {
  const accessToken = await getGoogleAccessToken();

  const stringData = {};
  Object.keys(data).forEach(k => {
    stringData[k] = typeof data[k] === 'string' ? data[k] : JSON.stringify(data[k]);
  });

  const messagePayload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        channel_id: channelId,
        ...stringData,
      },
      android: {
        priority: 'HIGH',
        notification: {
          channel_id: channelId,
          icon: 'ic_launcher',
          color: '#00D09C',
          sound: 'default',
          notification_priority: 'PRIORITY_MAX',
        },
      },
    },
  };

  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(messagePayload),
  });

  const result = await response.json();
  if (!response.ok) {
    throw new Error(`FCM API Error: ${JSON.stringify(result)}`);
  }
  return result;
}

// CLI Execution
if (require.main === module) {
  const args = process.argv.slice(2);
  const tokenArgIndex = args.indexOf('--token');
  const titleArgIndex = args.indexOf('--title');
  const bodyArgIndex = args.indexOf('--body');
  const typeArgIndex = args.indexOf('--type');

  const token = tokenArgIndex !== -1 ? args[tokenArgIndex + 1] : 'eB_B3XchTqG_FU_KbPtied:APA91bGyw2_y8nKGBpTueE2W6WSgIYB1vLRJYVW9Csm_Aai2PxTaLF_9UpcEzz8qXiL9GpuD8DzaCMXAEibDk-s1OZ8ayxJ9Ehv1uZSxvhJ2oHDeCvyoPkc';
  const title = titleArgIndex !== -1 ? args[titleArgIndex + 1] : '🔔 Grow Expense Live Test';
  const body = bodyArgIndex !== -1 ? args[bodyArgIndex + 1] : 'Aapka Firebase Push Notification setup 100% live hai!';
  const type = typeArgIndex !== -1 ? args[typeArgIndex + 1] : 'app_update';

  console.log(`Sending Push Notification to token: ${token.substring(0, 20)}...`);
  sendPushNotification({
    token,
    title,
    body,
    data: { type, title, body },
  })
    .then(res => {
      console.log('✅ FCM Message Dispatched Successfully!', res);
      process.exit(0);
    })
    .catch(err => {
      console.error('❌ FCM Dispatch Error:', err);
      process.exit(1);
    });
}

module.exports = { sendPushNotification, getGoogleAccessToken };
